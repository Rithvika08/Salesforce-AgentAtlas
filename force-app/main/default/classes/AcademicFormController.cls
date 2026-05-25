public without sharing class AcademicFormController {

    // LOAD FORM CONFIGURATION
    
    @AuraEnabled
    public static List<Map<String, Object>>
    loadFormConfiguration() {
    
        List<Map<String, Object>> result =
            new List<Map<String, Object>>();
    
        List<Form_Configuration_c__mdt> configs = [
    
            SELECT
    
                MasterLabel,
    
                Question_Id__c,
    
                Question_Type__c,
    
                Page_Number__c,
    
                Display_Order__c,
    
                Is_Required__c,
    
                Help_Text__c,
    
                Validation_Rule__c,
    
                Picklist_Values__c
    
            FROM Form_Configuration_c__mdt
    
            ORDER BY
    
                Page_Number__c,
    
                Display_Order__c
    
        ];
    
        for (
    
            Form_Configuration_c__mdt config
            : configs
    
        ) {
    
            Map<String, Object> fieldMap =
                new Map<String, Object>();
    
            // NEW FORMAT
    
            fieldMap.put(
                'id',
                config.Question_Id__c
            );
    
            fieldMap.put(
                'label',
                config.MasterLabel
            );
    
            fieldMap.put(
                'type',
                config.Question_Type__c
            );
    
            fieldMap.put(
                'page',
                Integer.valueOf(
                    config.Page_Number__c
                )
            );
    
            fieldMap.put(
                'displayOrder',
                Integer.valueOf(
                    config.Display_Order__c
                )
            );
    
            fieldMap.put(
                'required',
                config.Is_Required__c
            );
    
            fieldMap.put(
                'helpText',
                config.Help_Text__c
            );
    
            fieldMap.put(
                'validationRule',
                config.Validation_Rule__c
            );
    
            fieldMap.put(
                'picklistValues',
                config.Picklist_Values__c
            );
    
            // OLD FORMAT SUPPORT
    
            fieldMap.put(
                'MasterLabel',
                config.MasterLabel
            );
    
            fieldMap.put(
                'Question_Type__c',
                config.Question_Type__c
            );
    
            fieldMap.put(
                'Question_Id__c',
                config.Question_Id__c
            );
    
            fieldMap.put(
                'Page_Number__c',
                config.Page_Number__c
            );
    
            fieldMap.put(
                'Display_Order__c',
                config.Display_Order__c
            );
    
            fieldMap.put(
                'Is_Required__c',
                config.Is_Required__c
            );
    
            fieldMap.put(
                'Help_Text__c',
                config.Help_Text__c
            );
    
            fieldMap.put(
                'Validation_Rule__c',
                config.Validation_Rule__c
            );
    
            fieldMap.put(
                'Picklist_Values__c',
                config.Picklist_Values__c
            );
    
            result.add(fieldMap);
    
        }
    
        return result;
    
    }
    
    // LOAD FORM DRAFT
    
    @AuraEnabled
    public static Map<String, Object>
    loadFormDraft(Id userId) {
    
        Map<String, Object> result =
            new Map<String, Object>();
    
        List<Form_Submission__c> drafts = [
    
            SELECT
    
                Id,
    
                Current_Page__c,
    
                Status__c,
    
                User__c,
    
                (
    
                    SELECT
    
                        Id,
    
                        Question_Id__c,
    
                        Response_Value__c
    
                    FROM Form_Responses__r
    
                )
    
            FROM Form_Submission__c
    
            WHERE Status__c = 'In Progress'
    
            AND User__c =
                :UserInfo.getUserId()
    
            LIMIT 1
    
        ];
    
        if (!drafts.isEmpty()) {
    
            Form_Submission__c draft =
                drafts[0];
    
            result.put(
                'submissionId',
                draft.Id
            );
    
            result.put(
                'currentPage',
                draft.Current_Page__c
            );
    
            Map<String, Object> formData =
                new Map<String, Object>();
    
            for (
    
                Form_Response__c response
                : draft.Form_Responses__r
    
            ) {
    
                Map<String, Object> valueObj =
                    new Map<String, Object>();
    
                valueObj.put(
                    'value',
                    response.Response_Value__c
                );
    
                formData.put(
                    response.Question_Id__c,
                    valueObj
                );
    
            }
    
            result.put(
                'formData',
                formData
            );
    
        }
    
        return result;
    
    }
    
    // SAVE FORM DRAFT
    
    @AuraEnabled
    public static Map<String, Object>
    saveFormDraft(
    
        Id submissionId,
    
        Id userId,
    
        Integer currentPage,
    
        String formData,
    
        String sessionId
    
    ) {
    
        Map<String, Object> result =
            new Map<String, Object>();
    
        Form_Submission__c submission;
    
        /*
         * CREATE SUBMISSION
         */
    
        if (submissionId == null) {
    
            submission =
                new Form_Submission__c(
    
                    Status__c = 'In Progress',
    
                    Current_Page__c =
                        currentPage,
    
                    User__c =
                        UserInfo.getUserId(),
    
                    /*
                     * NEW FIELDS
                     */
    
                    Application_Type__c =
                        'Graduate Admission',
    
                    Total_Pages__c =
                        5,
    
                    Percent_Complete__c =
                        (currentPage * 100) / 5,
    
                    Started_Date__c =
                        System.now(),
    
                    Last_Saved__c =
                        System.now(),
    
                    Session_ID__c =
                        sessionId
    
                );
    
            insert submission;
    
        }
    
        /*
         * UPDATE SUBMISSION
         */
    
        else {
    
            submission = [
    
                SELECT
                    Id,
                    Current_Page__c,
                    User__c
    
                FROM Form_Submission__c
    
                WHERE Id = :submissionId
    
                LIMIT 1
    
            ];
    
            submission.Current_Page__c =
                currentPage;
    
            submission.Total_Pages__c =
                5;
    
            submission.Percent_Complete__c =
                (currentPage * 100) / 5;
    
            submission.Last_Saved__c =
                System.now();
    
            submission.Session_ID__c =
                sessionId;
    
            update submission;
    
        }
    
        /*
         * EXISTING RESPONSES
         */
    
        Map<String, Form_Response__c>
            existingResponses =
                new Map<String, Form_Response__c>();
    
        for (
    
            Form_Response__c existing :
    
            [
    
                SELECT
                    Id,
                    Question_Id__c,
                    Response_Value__c
    
                FROM Form_Response__c
    
                WHERE Form_Submission__c =
                    :submission.Id
    
            ]
    
        ) {
    
            existingResponses.put(
    
                existing.Question_Id__c,
    
                existing
    
            );
    
        }
    
        /*
         * PARSE FORM DATA
         */
    
        Map<String, Object> parsedData =
    
            (Map<String, Object>)
            JSON.deserializeUntyped(
                formData
            );
    
        /*
         * UPSERT LISTS
         */
    
        List<Form_Response__c>
            responsesToInsert =
                new List<Form_Response__c>();
    
        List<Form_Response__c>
            responsesToUpdate =
                new List<Form_Response__c>();
    
        /*
         * PROCESS RESPONSES
         */
    
        for (
    
            String key
            : parsedData.keySet()
    
        ) {
    
            Map<String, Object> valueObj =
    
                (Map<String, Object>)
                parsedData.get(key);
    
            String responseValue =
                String.valueOf(
                    valueObj.get('value')
                );
    
            /*
             * UPDATE EXISTING
             */
    
            if (
    
                existingResponses.containsKey(
                    key
                )
    
            ) {
    
                Form_Response__c existingResponse =
    
                    existingResponses.get(
                        key
                    );
    
                existingResponse.Response_Value__c =
                    responseValue;
    
                responsesToUpdate.add(
                    existingResponse
                );
    
            }
    
            /*
             * INSERT NEW
             */
    
            else {
    
                Form_Response__c newResponse =
                    new Form_Response__c(
    
                        Form_Submission__c =
                            submission.Id,
    
                        Question_Id__c =
                            key,
    
                        Response_Value__c =
                            responseValue
    
                    );
    
                responsesToInsert.add(
                    newResponse
                );
    
            }
    
        }
    
        /*
         * SAVE UPDATES
         */
    
        if (!responsesToUpdate.isEmpty()) {
    
            update responsesToUpdate;
    
        }
    
        /*
         * SAVE INSERTSss
         */
    
        if (!responsesToInsert.isEmpty()) {
    
            insert responsesToInsert;
    
        }
    
        /*
         * RETURN
         */
    
        result.put(
            'submissionId',
            submission.Id
        );
    
        return result;
    
    }
    
    // SUBMIT FORM
    
    @AuraEnabled
    public static Map<String, Object>
    submitForm(
    
        Id submissionId,
    
        String formData
    
    ) {
    
        Map<String, Object> result =
            new Map<String, Object>();
    
        Form_Submission__c submission = [
    
            SELECT
    
                Id,
    
                Status__c,
    
                User__c
    
            FROM Form_Submission__c
    
            WHERE Id = :submissionId
    
            LIMIT 1
    
        ];
    
        submission.Status__c =
            'Submitted';
    
        submission.Completed_Date__c =
            System.now();
    
        submission.Percent_Complete__c =
            100;
    
        submission.Total_Pages__c =
            5;
    
        submission.Last_Saved__c =
            System.now();
    
        update submission;
    
        result.put(
            'submissionId',
            submission.Id
        );
    
        return result;
    
    }
    
    }