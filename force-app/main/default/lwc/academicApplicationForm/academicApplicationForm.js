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

                // REACTIVE COPY

                this.formData =

                    JSON.parse(

                        JSON.stringify(

                            draftResult.formData || {}

                        )

                    );

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

        const filledData =
            event.detail.filledData;

        console.log(
            'AI FILLED:',
            JSON.stringify(
                filledData
            )
        );

        // MERGE DATA

        this.formData = {

            ...this.formData,

            ...filledData

        };

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

        // AUTO SAVE

        this.handleAutoSave();

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