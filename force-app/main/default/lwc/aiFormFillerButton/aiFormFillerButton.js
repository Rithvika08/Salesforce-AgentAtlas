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
            result.filledFields;

        this.filledFieldsCount =

            Object.keys(filledData).length;

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

                        confidence:
                            result.overallConfidence

                    }

                }

            );

        this.dispatchEvent(fillEvent);

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

        this.dispatchEvent(

            new CustomEvent('showdetails')

        );

    }

    // FIELD COUNT

    calculateTotalFields() {

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

        this.dispatchEvent(

            new ShowToastEvent({

                title: 'AI Fill Failed',

                message:

                    error.body?.message ||

                    'An error occurred while filling the form. Please try again.',

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