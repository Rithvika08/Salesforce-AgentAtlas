import { LightningElement, api } from 'lwc';

export default class Dynamicformpage extends LightningElement {

    @api currentPage;

    @api formData = {};

    @api sourceBreakdown = {};

    @api aiFieldMessages = {};

    @api compactLayout = false;

    // FULL FORM SCHEMA

    @api fullSchema = [];

    // PAGE TITLES

    pageTitles = {

        1: 'Personal Information',

        2: 'Contact Information',

        3: 'Educational Background',

        4: 'Program Selection & Academic Interests',

        5: 'Essays & Final Questions',

        6: 'Admin Review'

    };

    // FILTER + SORT CURRENT PAGE FIELDS

    get activePageData() {

        return {

            title: this.pageTitles[this.currentPage],

            fields: this.fullSchema

                ? this.fullSchema

                    .filter(q => {

                        return Number(

                            q.page ||

                            q.Page_Number__c

                        ) === Number(this.currentPage);

                    })

                    .sort((a, b) => {

                        return (

                            Number(
                                a.displayOrder ||
                                a.Display_Order__c ||
                                0
                            )

                            -

                            Number(
                                b.displayOrder ||
                                b.Display_Order__c ||
                                0
                            )

                        );

                    })

                : []

        };

    }

    // PAGE TITLE

    get pageTitle() {

        return this.activePageData.title;

    }

    // ACTIVE PAGE FIELDS

    get activeFields() {

        if (!this.activePageData.fields) {

            return [];

        }

        return this.activePageData.fields.map(field => {

            return {

                ...field,

                // SUPPORT BOTH OLD + NEW STRUCTURE

                id:
                    field.id ||
                    field.Question_Id__c,

                label:
                    field.label ||
                    field.MasterLabel,

                type:
                    field.type ||
                    field.Question_Type__c,

                required:
                    field.required ||
                    field.Is_Required__c,

                helpText:
                    field.helpText ||
                    field.Help_Text__c,

                validationRule:
                    field.validationRule ||
                    field.Validation_Rule__c,

                picklistValues:
                    field.picklistValues ||
                    field.Picklist_Values__c,

                currentValue:

                    this.formData[
                        field.id ||
                        field.Question_Id__c
                    ] !== undefined

                        ? this.formData[
                            field.id ||
                            field.Question_Id__c
                        ].value

                        : ''
                ,

                aiConfidence:

                    this.formData[
                        field.id ||
                        field.Question_Id__c
                    ]?.confidence,

                aiReasoning:

                    this.formData[
                        field.id ||
                        field.Question_Id__c
                    ]?.reasoning,

                aiSelectionType:

                    this.formData[
                        field.id ||
                        field.Question_Id__c
                    ]?.selectionType,

                aiSourceUpdatedAt:

                    this.formData[
                        field.id ||
                        field.Question_Id__c
                    ]?.sourceUpdatedAt,

                aiAlternativeOptions:

                    this.formData[
                        field.id ||
                        field.Question_Id__c
                    ]?.alternativeOptions,

                aiRawSourceFields:

                    this.formData[
                        field.id ||
                        field.Question_Id__c
                    ]?.sourceFields,

                originalAIValue:

                    this.formData[
                        field.id ||
                        field.Question_Id__c
                    ]?.originalAIValue,

                isAutoFilled:

                    this.formData[
                        field.id ||
                        field.Question_Id__c
                    ]?.isAutoFilled === true,

                isUserEdited:

                    this.formData[
                        field.id ||
                        field.Question_Id__c
                    ]?.isUserEdited === true,

                fieldStatus:

                    this.formData[
                        field.id ||
                        field.Question_Id__c
                    ]?.fieldStatus,

                canUndo:

                    this.canMoveFieldHistory(
                        field.id ||
                        field.Question_Id__c,
                        -1
                    ),

                canRedo:

                    this.canMoveFieldHistory(
                        field.id ||
                        field.Question_Id__c,
                        1
                    ),

                sourceFieldsText:

                    this.sanitizeSourceFieldsText(
                        this.sourceBreakdown[
                            field.id ||
                            field.Question_Id__c
                        ]?.sourcesText || ''
                    ),

                isMergedAnswer:

                    this.sourceBreakdown[
                        field.id ||
                        field.Question_Id__c
                    ]?.isMergedAnswer === true,

                aiMessage:

                    this.aiFieldMessages[
                        field.id ||
                        field.Question_Id__c
                    ] || ''

            };

        });

    }

    get fieldColumnClass() {

        return this.compactLayout
            ? 'slds-size_1-of-1 slds-p-around_small'
            : 'slds-size_1-of-1 slds-medium-size_1-of-2 slds-p-around_small';

    }

    sanitizeSourceFieldsText(sourceFieldsText) {

        let normalizedSourceFieldsText =
            sourceFieldsText;

        if (

            typeof normalizedSourceFieldsText === 'string' &&
            normalizedSourceFieldsText.trim().startsWith(
                '['
            )

        ) {

            try {

                const parsedSourceFields =
                    JSON.parse(
                        normalizedSourceFieldsText
                    );

                if (

                    Array.isArray(
                        parsedSourceFields
                    )

                ) {

                    normalizedSourceFieldsText =
                        parsedSourceFields.join(
                            ','
                        );

                }

            } catch (error) {

                normalizedSourceFieldsText =
                    sourceFieldsText;

            }

        }

        return String(
            normalizedSourceFieldsText || ''
        )
            .split(',')
            .map(sourceField => {

                return String(
                    sourceField || ''
                )
                    .replace(/^fields merged:\s*/i, '')
                    .replace(/^combined from:\s*/i, '')
                    .replace(/^extracted from:\s*/i, '')
                    .replace(/^fetched from:\s*/i, '')
                    .trim();

            })
            .filter(sourceField => {

                const lowerSource =
                    sourceField.toLowerCase();

                return sourceField &&
                    lowerSource !== 'prompt builder' &&
                    lowerSource !== 'einstein prompt builder' &&
                    lowerSource !== 'applicant knowledge' &&
                    lowerSource !== 'ai' &&
                    lowerSource !== 'chat prompt' &&
                    !lowerSource.includes(
                        'prompt builder'
                    ) &&
                    !lowerSource.includes(
                        'openai semantic extraction'
                    );

            })
            .join(', ');

    }

    // HANDLE FIELD CHANGE

    handleFieldChange(event) {

        this.dispatchEvent(

            new CustomEvent('fieldchange', {

                detail: event.detail

            })

        );

    }

    // VALIDATE ALL CHILD FIELDS

    @api
    validateAllFields() {

        const renderers =

            this.template.querySelectorAll(
                'c-form-field'
            );

        let allValid = true;

        renderers.forEach(renderer => {

            if (!renderer.validate()) {

                allValid = false;

            }

        });

        return allValid;

    }

    handleFieldRevert(event) {

        this.dispatchEvent(

            new CustomEvent('fieldrevert', {

                detail:
                    event.detail,

                bubbles:
                    true,

                composed:
                    true

            })

        );

    }

    handleFieldUndo(event) {

        this.dispatchEvent(

            new CustomEvent('fieldundo', {

                detail:
                    event.detail,

                bubbles:
                    true,

                composed:
                    true

            })

        );

    }

    handleFieldRedo(event) {

        this.dispatchEvent(

            new CustomEvent('fieldredo', {

                detail:
                    event.detail,

                bubbles:
                    true,

                composed:
                    true

            })

        );

    }

    canMoveFieldHistory(questionId, direction) {

        const fieldData =
            this.formData[questionId];

        if (

            !fieldData ||
            !Array.isArray(
                fieldData.valueHistory
            )

        ) {

            return false;

        }

        const currentIndex =
            Number.isInteger(
                fieldData.valueHistoryIndex
            )
                ? fieldData.valueHistoryIndex
                : fieldData.valueHistory.length - 1;

        const nextIndex =
            currentIndex + direction;

        return nextIndex >= 0 &&
            nextIndex < fieldData.valueHistory.length;

    }

    @api
    refreshValidityForFields(questionIds = []) {

        const ids =
            new Set(
                questionIds
            );

        const renderers =

            this.template.querySelectorAll(
                'c-form-field'
            );

        renderers.forEach(renderer => {

            const fieldId =
                renderer.fieldConfig?.id;

            if (

                ids.has(
                    fieldId
                )

            ) {

                renderer.validate();

            }

        });

    }

}
