import { LightningElement, api, track }
from 'lwc';

import { ShowToastEvent }
from 'lightning/platformShowToastEvent';

import fillFormWithAI
from '@salesforce/apex/AIFormFillerController.fillFormWithAI';

export default class AiFormFillerButton
    extends LightningElement {

    @api formData;

    @api currentPage;

    @api formConfig;

    @api submissionId;

    @track isProcessing = false;

    @track showResults = false;

    @track filledFieldsCount = 0;

    @track totalFieldsCount = 0;

    @track sourceBreakdown = [];

    @track processingMessage =
        'AI is analyzing your data...';

    buttonLabel = 'Fill with AI';

    showButton = true;

    showOptions = true;

    fillScope = 'fill-current';

    // LOAD

    connectedCallback() {

        this.totalFieldsCount =
            this.calculateTotalFields();

    }

    // HANDLE AI FILL

    async handleFillClick() {

        // CONFIRMATION

        const confirmed =
            await this.confirmFill();

        if (!confirmed) {

            return;

        }

        this.isProcessing = true;

        this.showButton = false;

        this.showResults = false;

        try {

            // STEP 1

            this.processingMessage =
                'Gathering previous application data...';

            await this.sleep(500);

            // STEP 2

            const result =
                await fillFormWithAI();

            // STEP 3

            this.processingMessage =
                'AI is filling your form...';

            await this.processResults(result);

            // STEP 4

            this.showCompletionMessage(result);

        }

        catch (error) {

            this.handleError(error);

        }

        finally {

            this.isProcessing = false;

            this.showButton = true;

        }

    }

    // PROCESS RESULTS

    async processResults(result) {

        const filledData =
            result?.filledFields || {};

        this.filledFieldsCount =

            Object.keys(filledData).length;

        this.sourceBreakdown =
            this.buildSourceBreakdown(
                filledData
            );

        // SEND DATA TO PARENT

        const fillEvent =
            new CustomEvent(

                'aifilled',

                {

                    detail: {

                        filledData:
                            filledData,

                        metadata:
                            result.metadata,

                        aiComparisonResults:
                            result.aiComparisonResults,

                        confidence:
                            result.overallConfidence

                    }

                }

            );

        this.dispatchEvent(fillEvent);
      //  System.debug(('fillEvent-->'+fillEvent));

        // VISUAL EFFECT

        await this.animateFieldFilling(
            filledData
        );

    }

    // ANIMATION

    async animateFieldFilling(filledData) {

        let count = 0;

        const interval = 100;

        for (const fieldId in filledData) {

            count++;

            this.processingMessage =

                `Filling field ${count}
                 of ${this.filledFieldsCount}...`;

            await this.sleep(interval);

        }

    }

    // SUCCESS MESSAGE

    showCompletionMessage(result) {

        this.showResults = true;

        const toastTitle =

            result.hasWarnings

                ? 'Form Partially Filled'

                : 'Form Filled Successfully';

        const toastVariant =

            result.hasWarnings

                ? 'warning'

                : 'success';

        let message =

            `${this.filledFieldsCount}
             fields filled automatically.`;

        this.dispatchEvent(

            new ShowToastEvent({

                title: toastTitle,

                message: message,

                variant: toastVariant,

                mode: 'sticky'

            })

        );

    }

    // CONFIRM

    confirmFill() {

        return new Promise((resolve) => {

            const message =

                this.fillScope === 'fill-all'

                    ? 'AI will fill all pages of your form using previous application data.'

                    : 'AI will fill the current page using previous application data.';

            resolve(confirm(message));

        });

    }

    // MENU

    handleMenuSelect(event) {

        const selectedValue =
            event.detail.value;

        switch (selectedValue) {

            case 'fill-all':

            case 'fill-current':

            case 'fill-empty':

                this.fillScope =
                    selectedValue;

                this.handleFillClick();

                break;

            case 'configure':

                this.openConfigurationModal();

                break;

            case 'sources':

                this.showDetailsModal();

                break;

        }

    }

    // CONFIG

    openConfigurationModal() {

        this.dispatchEvent(

            new CustomEvent('openconfig')

        );

    }

    // DETAILS

    showDetailsModal() {

        if (

            !this.hasSourceBreakdown

        ) {

            this.dispatchEvent(

                new ShowToastEvent({

                    title: 'No Source Details',

                    message:
                        'No combined source fields were returned for the latest fill.',

                    variant: 'info'

                })

            );

            return;

        }

        alert(
            this.sourceBreakdown.join(
                '\n\n'
            )
        );

        this.dispatchEvent(

            new CustomEvent(
                'showdetails',
                {
                    detail: {
                        sourceBreakdown:
                            this.sourceBreakdown
                    }
                }
            )

        );

    }

    get hasSourceBreakdown() {

        return Array.isArray(
            this.sourceBreakdown
        ) &&
            this.sourceBreakdown.length > 0;

    }

    get noSourceBreakdown() {

        return !this.hasSourceBreakdown;

    }

    buildSourceBreakdown(filledData) {

        return Object.keys(
            filledData || {}
        )
            .map(questionId => {

                const sourceFields =
                    filledData[questionId]?.sourceFields || [];

                const realSourceFields =
                    Array.isArray(
                        sourceFields
                    )
                        ? sourceFields
                            .map(sourceField => {

                                return this.normalizeSourceField(
                                    sourceField
                                );

                            })
                            .filter(sourceField => {

                                return !this.isGenericSourceField(
                                    sourceField
                                );

                            })
                        : [];

                if (

                    realSourceFields.length < 2

                ) {

                    return null;

                }

                return `${this.getQuestionLabel(questionId)}: ${realSourceFields.join(', ')}`;

            })
            .filter(Boolean);

    }

    normalizeSourceField(sourceField) {

        return String(
            sourceField || ''
        )
            .replace(/^fields merged:\s*/i, '')
            .replace(/^combined from:\s*/i, '')
            .replace(/^extracted from:\s*/i, '')
            .replace(/^fetched from:\s*/i, '')
            .trim();

    }

    isGenericSourceField(sourceField) {

        const lowerSource =
            this.normalizeSourceField(
                sourceField
            ).toLowerCase();

        return !lowerSource ||
            lowerSource === 'prompt builder' ||
            lowerSource === 'einstein prompt builder' ||
            lowerSource === 'applicant knowledge' ||
            lowerSource === 'ai' ||
            lowerSource === 'chat prompt' ||
            lowerSource.includes(
                'prompt builder'
            ) ||
            lowerSource.includes(
                'openai semantic extraction'
            );

    }

    getQuestionLabel(questionId) {

        const field =
            Array.isArray(
                this.formConfig
            )
                ? this.formConfig.find(config => {

                    return config.id === questionId ||
                        config.Question_Id__c === questionId ||
                        config.questionId === questionId;

                })
                : null;

        return field?.label ||
            field?.MasterLabel ||
            field?.questionText ||
            questionId;

    }

    // FIELD COUNT

    calculateTotalFields() {

        if (!Array.isArray(this.formConfig)) {

            return 0;

        }

        if (
            this.fillScope === 'fill-current'
        ) {

            return this.formConfig.filter(

                q =>

                    (q.page ||
                     q.Page_Number__c)

                    === this.currentPage

            ).length;

        }

        return this.formConfig.length;

    }

    // ERROR

    handleError(error) {

        console.error(
            'AI Fill Error:',
            error
        );

        const message =
            error?.body?.message ||
            error?.message ||
            'An error occurred while filling the form. Please try again.';

        console.error(
            'AI Fill Error Details:',
            JSON.stringify(
                {
                    status: error?.status,
                    statusText: error?.statusText,
                    message
                }
            )
        );

        this.dispatchEvent(

            new ShowToastEvent({

                title: 'AI Fill Failed',

                message:
                    message,

                variant: 'error'

            })

        );

    }

    // DELAY

    sleep(ms) {

        return new Promise(

            resolve =>
                setTimeout(resolve, ms)

        );

    }

}
