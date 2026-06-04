import { LightningElement, track }
from 'lwc';

import loadFormConfiguration
from '@salesforce/apex/AcademicFormController.loadFormConfiguration';

import loadFormDraft
from '@salesforce/apex/AcademicFormController.loadFormDraft';

import saveFormDraft
from '@salesforce/apex/AcademicFormController.saveFormDraft';

import submitForm
from '@salesforce/apex/AcademicFormController.submitForm';

export default class AcademicApplicationForm
    extends LightningElement {

    // FORM CONFIG

    @track schemaQuestions = [];

    // FORM DATA

    @track formData = {};

    // PAGE

    @track currentPage = 1;

    // SAVE STATUS

    @track isSaving = false;

    @track saveStatus = '';

    @track sourceBreakdown = [];

    @track sourceBreakdownByQuestion = {};

    @track aiComparisonResults = {};

    @track aiFieldMessages = {};

    // SUBMISSION

    @track isSubmitted = false;

    @track submittedReference = '';

    // SUBMISSION ID

    submissionId;

    // AUTOSAVE TIMER

    saveTimeout;

    // TOTAL PAGES

    totalPages = 5;

    // LOAD FORM

    connectedCallback() {

        this.initializeForm();

    }

    // INITIALIZE

    async initializeForm() {

        try {

            // LOAD CONFIGURATION

            const configResult =

                await loadFormConfiguration();

            // MAP CONFIG

            this.schemaQuestions =

                configResult.map(field => {

                    return {

                        id:
                            field.Question_Id__c,

                        label:
                            field.MasterLabel,

                        type:
                            field.Question_Type__c,

                        page:
                            Number(
                                field.Page_Number__c
                            ),

                        displayOrder:
                            Number(
                                field.Display_Order__c
                            ),

                        required:
                            field.Is_Required__c,

                        helpText:
                            field.Help_Text__c,

                        validationRule:
                            field.Validation_Rule__c,

                        // FIXED PICKLIST OPTIONS

                        options:
                            field.Picklist_Values__c

                                ? field
                                    .Picklist_Values__c
                                    .split(',')

                                    .map(option => {

                                        return {

                                            label:
                                                option.trim(),

                                            value:
                                                option.trim()

                                        };

                                    })

                                : []

                    };

                });

            console.log(
                'SCHEMA:',
                JSON.stringify(
                    this.schemaQuestions
                )
            );

            // LOAD DRAFT

            const draftResult =

                await loadFormDraft();

            console.log(
                'DRAFT:',
                JSON.stringify(
                    draftResult
                )
            );

            if (draftResult) {

                this.submissionId =
                    draftResult.submissionId;

                this.currentPage =
                    draftResult.currentPage || 1;

                const sanitizedDraft =
                    this.sanitizeFormData(
                        draftResult.formData || {}
                    );

                // REACTIVE COPY

                this.formData =

                    JSON.parse(

                        JSON.stringify(

                            sanitizedDraft.data

                        )

                    );

                this.sourceBreakdown =
                    this.buildSourceBreakdown(
                        this.formData
                    );

                this.sourceBreakdownByQuestion =
                    this.buildSourceBreakdownByQuestion(
                        this.sourceBreakdown
                    );

                if (

                    sanitizedDraft.changed

                ) {

                    await this.handleAutoSave();

                }

            }

        }

        catch(error) {

            console.error(
                'INIT ERROR:',
                JSON.stringify(error)
            );

        }

    }

    // FIELD CHANGE

    handleFieldChange(event) {

        const fieldId =
            event.detail.questionId;

        const value =
            event.detail.value;

        // UPDATE DATA

        this.formData = {

            ...this.formData,

            [fieldId]: {

                value: value

            }

        };

        this.clearFieldAIMessage(
            fieldId
        );

        console.log(
            'UPDATED FORM DATA:',
            JSON.stringify(
                this.formData
            )
        );

        // SAVE STATUS

        this.saveStatus =
            'Saving...';

        // CLEAR TIMER

        clearTimeout(this.saveTimeout);

        // AUTOSAVE

        this.saveTimeout =
            setTimeout(() => {

                this.handleAutoSave();

            }, 1000);

    }

    // AI FILLED EVENT

    handleAIFilled(event) {

        if (

            this.isQuestionPrompt(
                event.detail?.prompt
            )

        ) {

            console.warn(
                'Ignored AI/chat update because prompt was a question.'
            );

            return;

        }

        const filledData =
            this.formatFilledDataValues(
                this.filterValidFilledData(
                    event.detail.filledData || {}
                )
            );

        console.log(
            'AI FILLED:',
            JSON.stringify(
                filledData
            )
        );

        this.aiComparisonResults =
            event.detail.aiComparisonResults || {};

        this.clearFieldAIMessages(
            Object.keys(
                filledData
            )
        );

        if (

            Object.keys(
                this.aiComparisonResults
            ).length > 0

        ) {

            console.log(
                'AI COMPARISON RESULTS:',
                JSON.stringify(
                    this.aiComparisonResults
                )
            );

        }

        if (

            Object.keys(
                filledData
            ).length === 0

        ) {

            console.warn(
                'AI fill ignored because no valid field values were provided.'
            );

            return;

        }

        this.sourceBreakdown =
            this.buildSourceBreakdown(
                filledData
            );

        this.sourceBreakdownByQuestion =
            this.buildSourceBreakdownByQuestion(
                this.sourceBreakdown
            );

        // MERGE DATA

        const sanitizedMergedData =
            this.sanitizeFormData({

                ...this.formData,

                ...filledData

            }).data;

        this.formData =
            sanitizedMergedData;

        // FORCE REFRESH

        this.formData =
            JSON.parse(
                JSON.stringify(
                    this.formData
                )
            );

        console.log(
            'AI FORM DATA:',
            JSON.stringify(
                this.formData
            )
        );

        this.refreshAIFieldValidity(
            Object.keys(
                filledData
            )
        );

        // AUTO SAVE

        this.handleAutoSave();

    }

    handleFieldAIMessage(event) {

        const questionId =
            event.detail?.questionId;

        if (!questionId) {

            return;

        }

        this.aiFieldMessages = {

            ...this.aiFieldMessages,

            [questionId]:
                event.detail?.message || ''

        };

    }

    clearFieldAIMessage(questionId) {

        if (

            !questionId ||
            !this.aiFieldMessages[questionId]

        ) {

            return;

        }

        const nextMessages = {

            ...this.aiFieldMessages

        };

        delete nextMessages[questionId];

        this.aiFieldMessages =
            nextMessages;

    }

    clearFieldAIMessages(questionIds) {

        if (

            !Array.isArray(
                questionIds
            )

        ) {

            return;

        }

        const nextMessages = {

            ...this.aiFieldMessages

        };

        let changed = false;

        questionIds.forEach(questionId => {

            if (

                nextMessages[questionId]

            ) {

                delete nextMessages[questionId];
                changed = true;

            }

        });

        if (

            changed

        ) {

            this.aiFieldMessages =
                nextMessages;

        }

    }

    refreshAIFieldValidity(questionIds) {

        window.setTimeout(
            () => {

                const pageComponent =
                    this.template.querySelector(
                        'c-dynamicformpage'
                    );

                if (

                    pageComponent &&
                    typeof pageComponent.refreshValidityForFields ===
                        'function'

                ) {

                    pageComponent.refreshValidityForFields(
                        questionIds
                    );

                }

            },
            0
        );

    }

    buildSourceBreakdown(filledData) {

        return Object.keys(
            filledData || {}
        )
            .map(questionId => {

                const sourceFields =
                    this.parseSourceFields(
                        filledData[questionId]?.sourceFields
                    );

                const realSourceFields =
                    sourceFields
                        .map(sourceField => {

                            return this.normalizeSourceField(
                                sourceField
                            );

                        })
                        .filter(sourceField => {

                            return !this.isGenericSourceField(
                                sourceField
                            );

                        });

                if (

                    realSourceFields.length < 2

                ) {

                    return null;

                }

                return {
                    id:
                        questionId,
                    label:
                        this.getQuestionLabel(
                            questionId
                        ),
                    sourcesText:
                        realSourceFields
                            .map(sourceField => {

                                return this.formatSourceField(
                                    sourceField
                                );

                            })
                            .join(', ')
                };

            })
            .filter(Boolean);

    }

    buildSourceBreakdownByQuestion(sourceBreakdown) {

        return (sourceBreakdown || []).reduce(
            (breakdownByQuestion, item) => {

                breakdownByQuestion[item.id] =
                    item;

                return breakdownByQuestion;

            },
            {}
        );

    }

    parseSourceFields(sourceFields) {

        if (

            Array.isArray(
                sourceFields
            )

        ) {

            return sourceFields.reduce(
                (parsedFields, sourceField) => {

                    parsedFields.push(
                        ...this.parseSourceFields(
                            sourceField
                        )
                    );

                    return parsedFields;

                },
                []
            );

        }

        if (

            typeof sourceFields === 'string' &&
            sourceFields.trim()

        ) {

            const trimmedSourceFields =
                sourceFields.trim();

            if (

                trimmedSourceFields.startsWith(
                    '['
                )

            ) {

                try {

                    const parsedSourceFields =
                        JSON.parse(
                            trimmedSourceFields
                        );

                    if (

                        Array.isArray(
                            parsedSourceFields
                        )

                    ) {

                        return parsedSourceFields;

                    }

                } catch (error) {

                    // Fall through to comma parsing.

                }

            }

            return trimmedSourceFields.split(
                ','
            )
                .map(sourceField => sourceField.trim())
                .filter(sourceField => sourceField);

        }

        return [];

    }

    isGenericSourceField(sourceField) {

        const normalizedSource =
            this.normalizeSourceField(
                sourceField
            );

        const lowerSource =
            normalizedSource.toLowerCase();

        return lowerSource.includes(
            'openai semantic extraction'
        ) ||
            lowerSource.includes(
                'prompt builder'
            ) ||
            lowerSource === 'prompt builder' ||
            lowerSource === 'einstein prompt builder' ||
            lowerSource === 'applicant knowledge' ||
            lowerSource === 'ai' ||
            lowerSource === 'chat prompt';

    }

    normalizeSourceField(sourceField) {

        return String(
            sourceField || ''
        )
            .replace(/^["'\[]+/g, '')
            .replace(/["'\]]+$/g, '')
            .replace(/^fields merged:\s*/i, '')
            .replace(/^combined from:\s*/i, '')
            .replace(/^extracted from:\s*/i, '')
            .replace(/^fetched from:\s*/i, '')
            .trim();

    }

    getQuestionLabel(questionId) {

        const fieldConfig =
            this.schemaQuestions.find(field => {

                return field.id === questionId;

            });

        return fieldConfig?.label || questionId;

    }

    formatSourceField(sourceField) {

        return String(
            sourceField || ''
        )
            .replace(/__c$/g, '')
            .replace(/_/g, ' ')
            .replace(/\./g, ' ');

    }

    get hasSourceBreakdown() {

        return this.sourceBreakdown.length > 0;

    }

    filterValidFilledData(filledData) {

        const validData = {};

        Object.keys(
            filledData
        ).forEach(questionId => {

            const fieldConfig =
                this.schemaQuestions.find(field => {

                    return field.id === questionId;

                });

            if (

                !fieldConfig

            ) {

                return;

            }

            const fieldValue =
                filledData[questionId]?.value;

            if (

                this.isValidFieldValue(
                    fieldValue,
                    fieldConfig
                )

            ) {

                validData[questionId] =
                    filledData[questionId];

            }

            else {

                console.warn(
                    `Ignored invalid value for ${fieldConfig.label}: ${fieldValue}`
                );

            }

        });

        return validData;

    }

    formatFilledDataValues(filledData) {

        const formattedData = {};

        Object.keys(
            filledData || {}
        ).forEach(questionId => {

            const fieldConfig =
                this.schemaQuestions.find(field => {

                    return field.id === questionId;

                });

            const fieldData =
                filledData[questionId];

            formattedData[questionId] = {
                ...fieldData,
                value:
                    this.formatGeneratedValueForField(
                        fieldData?.value,
                        fieldConfig
                    )
            };

        });

        return formattedData;

    }

    formatGeneratedValueForField(

        value,

        fieldConfig

    ) {

        if (

            !this.isContactInformationField(
                fieldConfig
            )

        ) {

            return value;

        }

        return this.formatContactInformationValue(
            value
        );

    }

    isContactInformationField(fieldConfig) {

        const fieldLabel =
            String(
                fieldConfig?.label || ''
            )
                .toLowerCase()
                .replace(/[^a-z0-9]+/g, ' ')
                .replace(/\s+/g, ' ')
                .trim();

        return fieldLabel === 'contact information' ||
            fieldLabel === 'contact info' ||
            fieldLabel.includes(
                'contact information'
            ) ||
            fieldLabel.includes(
                'contact details'
            );

    }

    formatContactInformationValue(value) {

        const rawValue =
            String(
                value || ''
            )
                .replace(/\s+/g, ' ')
                .trim();

        if (

            !rawValue

        ) {

            return value;

        }

        const lowerValue =
            rawValue.toLowerCase();

        if (

            lowerValue.includes(
                'you can reach me by'
            ) ||
            (
                lowerValue.startsWith(
                    'my mailing address is'
                ) &&
                (
                    lowerValue.includes(
                        'phone at'
                    ) ||
                    lowerValue.includes(
                        'email at'
                    )
                )
            )

        ) {

            return this.cleanContactInformationSentence(
                rawValue
            );

        }

        const emailMatch =
            rawValue.match(
                /(?:email|e-mail)\s*:\s*([A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,})/i
            );

        const phoneMatch =
            rawValue.match(
                /(?:phone|mobile|telephone|contact number)\s*:\s*([+()0-9][+()0-9\s.-]{5,}[0-9])/i
            );

        const email =
            emailMatch
                ? emailMatch[1].trim()
                : '';

        const phone =
            phoneMatch
                ? phoneMatch[1]
                    .replace(/[.;,]+$/g, '')
                    .trim()
                : '';

        let address =
            rawValue
                .replace(
                    /(?:phone|mobile|telephone|contact number)\s*:\s*[+()0-9][+()0-9\s.-]{5,}[0-9][.;,]?\s*/gi,
                    ''
                )
                .replace(
                    /(?:email|e-mail)\s*:\s*[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}[.;,]?\s*/gi,
                    ''
                )
                .replace(/\s+/g, ' ')
                .trim();

        address =
            address
                .replace(
                    /^my mailing address is\s+/i,
                    ''
                )
                .replace(/[.;,]+$/g, '');

        const sentences =
            [];

        if (

            address

        ) {

            sentences.push(
                `My mailing address is ${address}.`
            );

        }

        const contactParts =
            [];

        if (

            phone

        ) {

            contactParts.push(
                `phone at ${phone}`
            );

        }

        if (

            email

        ) {

            contactParts.push(
                `email at ${email}`
            );

        }

        if (

            contactParts.length > 0

        ) {

            sentences.push(
                `You can reach me by ${this.joinHumanReadable(contactParts)}.`
            );

        }

        return sentences.length > 0
            ? sentences.join(' ')
            : value;

    }

    cleanContactInformationSentence(value) {

        let cleanedValue =
            String(
                value || ''
            )
                .replace(/\s+/g, ' ')
                .trim();

        cleanedValue =
            cleanedValue.replace(
                /^(my mailing address is\s*){2,}/i,
                'My mailing address is '
            );

        cleanedValue =
            cleanedValue.replace(
                /^my mailing address is\s+(?=you can reach me by)/i,
                ''
            );

        cleanedValue =
            cleanedValue.replace(
                /^my mailing address is\s+(?=phone at|email at)/i,
                'You can reach me by '
            );

        cleanedValue =
            cleanedValue.replace(
                /\s+(?=You can reach me by)/,
                '. '
            );

        cleanedValue =
            cleanedValue.replace(
                /\.\s*\./g,
                '.'
            );

        return cleanedValue;

    }

    joinHumanReadable(values) {

        const filteredValues =
            (values || []).filter(Boolean);

        if (

            filteredValues.length <= 1

        ) {

            return filteredValues[0] || '';

        }

        if (

            filteredValues.length === 2

        ) {

            return `${filteredValues[0]} and ${filteredValues[1]}`;

        }

        return `${filteredValues
            .slice(0, -1)
            .join(', ')}, and ${filteredValues[filteredValues.length - 1]}`;

    }

    sanitizeFormData(formData) {

        const sanitizedData = {};
        let changed = false;

        Object.keys(
            formData || {}
        ).forEach(questionId => {

            const fieldConfig =
                this.schemaQuestions.find(field => {

                    return field.id === questionId;

                });

            if (

                !fieldConfig

            ) {

                sanitizedData[questionId] =
                    formData[questionId];

                return;

            }

            const fieldValue =
                formData[questionId]?.value;

            if (

                this.isValidFieldValue(
                    fieldValue,
                    fieldConfig
                )

            ) {

                sanitizedData[questionId] =
                    formData[questionId];

            }

            else {

                changed = true;

                console.warn(
                    `Removed invalid saved value for ${fieldConfig.label}: ${fieldValue}`
                );

            }

        });

        return {
            data:
                sanitizedData,
            changed:
                changed
        };

    }

    isValidFieldValue(

        value,

        fieldConfig

    ) {

        if (

            value === '' ||
            value === null ||
            value === undefined

        ) {

            return true;

        }

        const fieldType =
            String(
                fieldConfig.type || ''
            ).toLowerCase();

        if (

            this.isEssayField(
                fieldConfig
            )

        ) {

            return this.isMeaningfulEssayValue(
                value
            );

        }

        if (

            this.isDateField(
                fieldConfig
            )

        ) {

            return this.isValidDateValue(
                value
            );

        }

        if (

            fieldType === 'number'

        ) {

            return !Number.isNaN(
                Number(value)
            );

        }

        if (

            this.isEmailField(
                fieldConfig
            )

        ) {

            return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(
                value
            );

        }

        if (

            this.isPhoneField(
                fieldConfig
            )

        ) {

            return this.isValidPhoneValue(
                value
            );

        }

        return true;

    }

    isEssayField(fieldConfig) {

        const fieldType =
            String(
                fieldConfig.type || ''
            ).toLowerCase();

        const fieldLabel =
            String(
                fieldConfig.label || ''
            ).toLowerCase();

        return fieldType === 'textarea' &&
            (
                fieldLabel.includes(
                    'statement of purpose'
                ) ||
                fieldLabel.includes(
                    'purpose statement'
                ) ||
                fieldLabel.includes(
                    'personal statement'
                ) ||
                fieldLabel.includes(
                    'personal essay'
                )
            );

    }

    isMeaningfulEssayValue(value) {

        const normalizedValue =
            String(value || '')
                .toLowerCase()
                .replace(/[^a-z0-9]+/g, ' ')
                .replace(/\s+/g, ' ')
                .trim();

        if (

            normalizedValue.length < 80

        ) {

            return false;

        }

        return normalizedValue
            .split(' ')
            .filter(Boolean)
            .length >= 12;

    }

    isDateField(fieldConfig) {

        const fieldType =
            String(
                fieldConfig.type || ''
            ).toLowerCase();

        const fieldLabel =
            String(
                fieldConfig.label || ''
            ).toLowerCase();

        return fieldType === 'date' ||
            fieldLabel.includes('date');

    }

    isEmailField(fieldConfig) {

        const fieldType =
            String(
                fieldConfig.type || ''
            ).toLowerCase();

        const fieldLabel =
            String(
                fieldConfig.label || ''
            ).toLowerCase();

        return fieldType === 'email' ||
            fieldLabel.includes('email');

    }

    isPhoneField(fieldConfig) {

        const fieldType =
            String(
                fieldConfig.type || ''
            ).toLowerCase();

        return fieldType === 'phone';

    }

    isValidPhoneValue(value) {

        const phoneValue =
            String(
                value || ''
            ).trim();

        if (

            !phoneValue

        ) {

            return true;

        }

        const digitCount =
            (
                phoneValue.match(
                    /\d/g
                ) || []
            ).length;

        return digitCount >= 7 &&
            /^[+()0-9\s.-]+$/.test(
                phoneValue
            );

    }

    isValidDateValue(value) {

        if (

            !/^\d{4}-\d{2}-\d{2}$/.test(
                value
            )

        ) {

            return false;

        }

        const parsedDate =
            new Date(
                `${value}T00:00:00`
            );

        return !Number.isNaN(
            parsedDate.getTime()
        ) &&
            parsedDate.toISOString()
                .startsWith(
                    value
                );

    }

    isQuestionPrompt(prompt) {

        const normalizedPrompt =
            String(prompt || '')
                .toLowerCase()
                .replace(/[^a-z0-9]+/g, ' ')
                .replace(/\s+/g, ' ')
                .trim();

        if (

            this.hasFormActionIntent(
                normalizedPrompt
            )

        ) {

            return false;

        }

        return String(prompt || '').trim().endsWith('?') ||
            normalizedPrompt.startsWith('do you think') ||
            normalizedPrompt.startsWith('dont you think') ||
            normalizedPrompt.startsWith('don t you think') ||
            normalizedPrompt.startsWith('do not you think') ||
            normalizedPrompt.includes(' you think ') ||
            normalizedPrompt.startsWith('why ') ||
            normalizedPrompt.startsWith('what ') ||
            normalizedPrompt.startsWith('how ') ||
            normalizedPrompt.startsWith('when ') ||
            normalizedPrompt.startsWith('where ') ||
            normalizedPrompt.startsWith('who ') ||
            normalizedPrompt.includes('can you check') ||
            normalizedPrompt.includes('could you check') ||
            normalizedPrompt.includes('please check') ||
            normalizedPrompt.includes('not sure') ||
            normalizedPrompt.includes('verify') ||
            normalizedPrompt.includes('is correct') ||
            normalizedPrompt.includes('looks correct');

    }

    hasFormActionIntent(normalizedPrompt) {

        return normalizedPrompt.includes('fill') ||
            normalizedPrompt.includes('autofill') ||
            normalizedPrompt.includes('auto fill') ||
            normalizedPrompt.includes('populate') ||
            normalizedPrompt.includes('complete') ||
            normalizedPrompt.includes('clear') ||
            normalizedPrompt.includes('remove') ||
            normalizedPrompt.includes('delete') ||
            normalizedPrompt.includes('replace') ||
            normalizedPrompt.includes('change') ||
            normalizedPrompt.includes('update') ||
            normalizedPrompt.includes('set') ||
            normalizedPrompt.includes('enter') ||
            normalizedPrompt.includes('put') ||
            normalizedPrompt.includes('use');

    }

    // NEXT

    async handleNext() {

        const pageComponent =

            this.template.querySelector(
                'c-dynamicformpage'
            );

        if (

            pageComponent &&

            !pageComponent.validateAllFields()

        ) {

            return;

        }

        // SAVE

        await this.handleAutoSave();

        if (
            this.currentPage <
            this.totalPages
        ) {

            this.currentPage += 1;

        }

    }

    // PREVIOUS

    async handlePrevious() {

        // SAVE

        await this.handleAutoSave();

        if (this.currentPage > 1) {

            this.currentPage -= 1;

        }

    }

    // AUTO SAVE

    async handleAutoSave() {

        try {

            this.isSaving = true;

            this.saveStatus =
                'Saving...';

            const result =

                await saveFormDraft({

                    submissionId:
                        this.submissionId,

                    userId: null,

                    currentPage:
                        this.currentPage,

                    formData:
                        JSON.stringify(
                            this.formData
                        ),

                    sessionId: null

                });

            this.submissionId =
                result.submissionId;

            this.saveStatus =
                'Saved';

            setTimeout(() => {

                this.saveStatus = '';

            }, 2000);

        }

        catch(error) {

            console.error(
                'SAVE ERROR:',
                JSON.stringify(error)
            );

            this.saveStatus =
                'Save Failed';

        }

        finally {

            this.isSaving = false;

        }

    }

    // SUBMIT

    async handleSubmit() {

        try {

            // FINAL SAVE

            await this.handleAutoSave();

            const result =

                await submitForm({

                    submissionId:
                        this.submissionId,

                    formData:
                        JSON.stringify(
                            this.formData
                        )

                });

            this.submittedReference =
                result.submissionId;

            this.isSubmitted = true;

        }

        catch(error) {

            console.error(
                'SUBMIT ERROR:',
                JSON.stringify(error)
            );

        }

    }

    // HELPERS

    get isFirstPage() {

        return this.currentPage === 1;

    }

    get isLastPage() {

        return this.currentPage ===
               this.totalPages;

    }

}
