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

            String confidenceFieldApiName =
                getFormResponseConfidenceFieldApiName();

            Map<Id, Object> confidenceByResponseId =
                getSavedResponseConfidenceById(
                    draft.Id,
                    confidenceFieldApiName
                );
    
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

                if (
                    confidenceByResponseId.containsKey(
                        response.Id
                    )
                ) {

                    valueObj.put(
                        'confidence',
                        normalizeStoredConfidenceForFormData(
                            confidenceFieldApiName,
                            confidenceByResponseId.get(
                                response.Id
                            )
                        )
                    );

                }
    
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

        try {
    
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
            String.isBlank(
                formData
            )
                ? new Map<String, Object>()
                : (Map<String, Object>)
                    JSON.deserializeUntyped(
                        formData
                    );

        String confidenceFieldApiName =
            getFormResponseConfidenceFieldApiName();

        Integer responseValueMaxLength =
            getFieldLength(
                Form_Response__c.Response_Value__c
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
    
            Object rawValueObj =
                parsedData.get(key);

            if (
                !(rawValueObj instanceof Map<String, Object>)
            ) {

                continue;

            }

            Map<String, Object> valueObj =

                (Map<String, Object>)
                rawValueObj;
    
            String responseValue =
                valueObj != null &&
                valueObj.containsKey('value') &&
                valueObj.get('value') != null
                    ? String.valueOf(
                        valueObj.get('value')
                    )
                    : null;

            if (
                String.isBlank(
                    responseValue
                )
            ) {

                if (

                    existingResponses.containsKey(
                        key
                    )

                ) {

                    Form_Response__c existingBlankResponse =

                        existingResponses.get(
                            key
                        );

                    existingBlankResponse.Response_Value__c =
                        '';

                    responsesToUpdate.add(
                        existingBlankResponse
                    );

                }

                continue;

            }

            responseValue =
                truncateToFieldLength(
                    responseValue,
                    responseValueMaxLength
                );

            Decimal confidence =
                getResponseConfidence(
                    valueObj
                );

            Boolean confidenceProvided =
                hasResponseConfidence(
                    valueObj
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

                applyResponseConfidence(
                    existingResponse,
                    confidenceFieldApiName,
                    confidence,
                    confidenceProvided
                );
    
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

                applyResponseConfidence(
                    newResponse,
                    confidenceFieldApiName,
                    confidence,
                    confidenceProvided
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
    
            saveResponsesWithoutBlockingDraft(
                responsesToUpdate,
                result,
                'updated'
            );
    
        }

        /*
         * SAVE INSERTSss
         */
    
        if (!responsesToInsert.isEmpty()) {
    
            saveResponsesWithoutBlockingDraft(
                responsesToInsert,
                result,
                'inserted'
            );
    
        }
    
        /*
         * RETURN
         */
    
        result.put(
            'submissionId',
            submission.Id
        );

        result.put(
            'success',
            true
        );
    
        return result;

        } catch (Exception e) {

            result.put(
                'success',
                false
            );

            result.put(
                'errorMessage',
                e.getTypeName() +
                ': ' +
                e.getMessage()
            );

            return result;

        }
    
    }

    private static Integer getFieldLength(

        Schema.SObjectField fieldToken

    ) {

        if (
            fieldToken == null
        ) {

            return 0;

        }

        try {

            return fieldToken
                .getDescribe()
                .getLength();

        } catch (Exception e) {

            return 0;

        }

    }

    private static String truncateToFieldLength(

        String value,

        Integer maxLength

    ) {

        if (
            String.isBlank(
                value
            ) ||
            maxLength == null ||
            maxLength <= 0 ||
            value.length() <= maxLength
        ) {

            return value;

        }

        return value.substring(
            0,
            maxLength
        );

    }

    private static void saveResponsesWithoutBlockingDraft(

        List<Form_Response__c> responses,

        Map<String, Object> result,

        String operation

    ) {

        if (
            responses == null ||
            responses.isEmpty()
        ) {

            return;

        }

        Database.SaveResult[] saveResults;

        if (
            operation == 'inserted'
        ) {

            saveResults =
                Database.insert(
                    responses,
                    false
                );

        } else {

            saveResults =
                Database.update(
                    responses,
                    false
                );

        }

        List<String> errors =
            (List<String>) result.get(
                'responseSaveErrors'
            );

        if (
            errors == null
        ) {

            errors =
                new List<String>();

        }

        Integer savedCount = 0;

        for (
            Integer index = 0;
            index < saveResults.size();
            index++
        ) {

            Database.SaveResult saveResult =
                saveResults[index];

            if (
                saveResult.isSuccess()
            ) {

                savedCount++;
                continue;

            }

            Form_Response__c response =
                responses[index];

            for (
                Database.Error error :
                saveResult.getErrors()
            ) {

                errors.add(
                    String.valueOf(
                        response.Question_Id__c
                    ) +
                    ': ' +
                    error.getMessage()
                );

            }

        }

        result.put(
            operation + 'ResponseCount',
            savedCount
        );

        if (
            !errors.isEmpty()
        ) {

            result.put(
                'responseSaveErrors',
                errors
            );

        }

    }

    private static Map<Id, Object> getSavedResponseConfidenceById(

        Id submissionId,

        String confidenceFieldApiName

    ) {

        Map<Id, Object> confidenceByResponseId =
            new Map<Id, Object>();

        if (
            submissionId == null ||
            String.isBlank(
                confidenceFieldApiName
            )
        ) {

            return confidenceByResponseId;

        }

        String query =
            'SELECT Id, ' +
            confidenceFieldApiName +
            ' FROM Form_Response__c WHERE Form_Submission__c = :submissionId';

        for (
            SObject response :
            Database.query(
                query
            )
        ) {

            Object confidence =
                response.get(
                    confidenceFieldApiName
                );

            if (
                confidence != null
            ) {

                confidenceByResponseId.put(
                    (Id) response.get(
                        'Id'
                    ),
                    confidence
                );

            }

        }

        return confidenceByResponseId;

    }

    private static String getFormResponseConfidenceFieldApiName() {

        Map<String, Schema.SObjectField> fieldMap =
            Form_Response__c.SObjectType.getDescribe().fields.getMap();

        for (
            String candidate :
            new List<String>{
                'Confidence__c',
                'AI_Confidence__c',
                'Match_Confidence__c',
                'Field_Confidence__c',
                'Field_Match_Confidence__c',
                'Extraction_Confidence__c',
                'AI_Extraction_Confidence__c',
                'Confidence_Score__c',
                'AI_Confidence_Score__c'
            }
        ) {

            if (
                fieldMap.containsKey(
                    candidate
                )
            ) {

                return candidate;

            }

        }

        return null;

    }

    private static Decimal getResponseConfidence(

        Map<String, Object> valueObj

    ) {

        if (
            valueObj == null
        ) {

            return null;

        }

        Object rawConfidence =
            valueObj.containsKey(
                'confidence'
            )
                ? valueObj.get(
                    'confidence'
                )
                : valueObj.get(
                    'bestMatchConfidence'
                );

        if (
            rawConfidence == null ||
            String.isBlank(
                String.valueOf(
                    rawConfidence
                )
            )
        ) {

            return null;

        }

        try {

            return Decimal.valueOf(
                String.valueOf(
                    rawConfidence
                ).replace(
                    '%',
                    ''
                )
            );

        } catch (Exception e) {

            return null;

        }

    }

    private static Boolean hasResponseConfidence(

        Map<String, Object> valueObj

    ) {

        return valueObj != null &&
            (
                valueObj.containsKey(
                    'confidence'
                ) ||
                valueObj.containsKey(
                    'bestMatchConfidence'
                )
            );

    }

    private static Object normalizeStoredConfidenceForFormData(

        String confidenceFieldApiName,

        Object storedConfidence

    ) {

        if (
            storedConfidence == null ||
            String.isBlank(
                confidenceFieldApiName
            )
        ) {

            return storedConfidence;

        }

        Schema.DescribeFieldResult fieldDescribe =
            Form_Response__c.SObjectType
                .getDescribe()
                .fields
                .getMap()
                .get(
                    confidenceFieldApiName
                )
                .getDescribe();

        if (
            fieldDescribe.getType() !=
            Schema.DisplayType.Percent
        ) {

            return storedConfidence;

        }

        try {

            Decimal confidence =
                Decimal.valueOf(
                    String.valueOf(
                        storedConfidence
                    )
                );

            return confidence > 1
                ? confidence / 100
                : confidence;

        } catch (Exception e) {

            return storedConfidence;

        }

    }

    private static void applyResponseConfidence(

        Form_Response__c response,

        String confidenceFieldApiName,

        Decimal confidence,

        Boolean confidenceProvided

    ) {

        if (
            response == null ||
            String.isBlank(
                confidenceFieldApiName
            )
        ) {

            return;

        }

        Schema.DescribeFieldResult fieldDescribe =
            Form_Response__c.SObjectType
                .getDescribe()
                .fields
                .getMap()
                .get(
                    confidenceFieldApiName
                )
                .getDescribe();

        if (
            confidence == null
        ) {

            if (
                confidenceProvided == false
            ) {

                response.put(
                    confidenceFieldApiName,
                    null
                );

            }

            return;

        }

        Decimal numericValueToStore =
            confidence;

        if (
            fieldDescribe.getType() ==
            Schema.DisplayType.Percent &&
            numericValueToStore <= 1
        ) {

            numericValueToStore =
                numericValueToStore * 100;

        }

        if (
            fieldDescribe.getType() ==
            Schema.DisplayType.Percent &&
            fieldDescribe.getScale() == 0
        ) {

            numericValueToStore =
                numericValueToStore.setScale(
                    0
                );

        }

        if (
            fieldDescribe.getType() ==
            Schema.DisplayType.String ||
            fieldDescribe.getType() ==
            Schema.DisplayType.TextArea
        ) {

            response.put(
                confidenceFieldApiName,
                String.valueOf(
                    numericValueToStore
                )
            );

        } else {

            response.put(
                confidenceFieldApiName,
                numericValueToStore
            );

        }

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
