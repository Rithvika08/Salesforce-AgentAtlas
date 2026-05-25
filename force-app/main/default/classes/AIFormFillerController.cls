public without sharing class AIFormFillerController {

    @AuraEnabled
    public static Map<String, Object>
    fillFormWithAI() {

        /*
         * FINAL RESPONSE
         */

        Map<String, Object> response =
            new Map<String, Object>();

        /*
         * FILLED FIELDS
         */

        Map<String, Object> filledFields =
            new Map<String, Object>();

        /*
         * QUESTION LIST
         */

        List<UserDataDiscoveryService.FormQuestion>
            questions =
                new List<UserDataDiscoveryService.FormQuestion>();

        /*
         * LOAD QUESTIONS FROM METADATA
         */

        for (

            Form_Configuration_c__mdt q :

            [

                SELECT
                    Question_Id__c,
                    MasterLabel,
                    Question_Type__c,
                    Display_Order__c

                FROM Form_Configuration_c__mdt

                ORDER BY Display_Order__c ASC

            ]

        ) {

            UserDataDiscoveryService.FormQuestion question =
                new UserDataDiscoveryService.FormQuestion();

            question.questionId =
                q.Question_Id__c;

            question.questionText =
                q.MasterLabel;

            question.questionType =
                q.Question_Type__c;

            questions.add(question);

        }

        /*
         * RUN DISCOVERY
         */

        Map<String, UserDataDiscoveryService.DataDiscoveryResult>
            discoveryResults =
                UserDataDiscoveryService.discoverDataForForm(
                    UserInfo.getUserId(),
                    questions
                );

        Decimal totalConfidence = 0;

        Integer confidenceCount = 0;

        /*
         * BUILD RESPONSE
         */

        for (

            String questionId
            : discoveryResults.keySet()

        ) {

            UserDataDiscoveryService.DataDiscoveryResult result =
                discoveryResults.get(questionId);

            if (

                result != null &&

                !String.isBlank(
                    result.recommendedValue
                )

            ) {

                filledFields.put(

                    questionId,

                    new Map<String, Object>{

                        'value' =>
                            result.recommendedValue,

                        'confidence' =>
                            result.bestMatchConfidence,

                        'reasoning' =>
                            result.reasoning,

                        'sourceFields' =>
                            result.sourceFields

                    }

                );

                if (

                    result.bestMatchConfidence
                        != null

                ) {

                    totalConfidence +=
                        result.bestMatchConfidence;

                    confidenceCount++;

                }

            }

        }

        /*
         * OVERALL CONFIDENCE
         */

        Decimal overallConfidence = 0;

        if (confidenceCount > 0) {

            overallConfidence =
                totalConfidence /
                confidenceCount;

        }

        /*
         * FINAL PAYLOAD
         */

        response.put(
            'filledFields',
            filledFields
        );

        response.put(
            'overallConfidence',
            overallConfidence
        );

        response.put(
            'hasWarnings',
            false
        );

        response.put(
            'unfillableFields',
            0
        );

        response.put(
            'clarificationsNeeded',
            0
        );

        return response;

    }

}