public without sharing class EinsteinPromptExtractionService {

    /*
     * Prompt Builder template API name shared with chat command interpretation.
     */
    private static final String PROMPT_TEMPLATE_API_NAME =
        'AI_Form_Chat_Command_Interpreter';

    public static Map<String, UserDataDiscoveryService.DataDiscoveryResult>
    extractAnswers(

        Id userId,

        List<UserDataDiscoveryService.FormQuestion> questions

    ) {

        Map<String, UserDataDiscoveryService.DataDiscoveryResult> results =
            new Map<String, UserDataDiscoveryService.DataDiscoveryResult>();

        if (

            questions == null ||

            questions.isEmpty()

        ) {

            return results;

        }

        UserDataDiscoveryService.DiscoveryContext context =
            UserDataDiscoveryService.loadDiscoveryContext(
                userId
            );

        String promptResponse =
            invokePromptTemplate(
                'fill all fields',
                JSON.serialize(
                    buildFieldContext(
                        questions
                    )
                ),
                '{}',
                JSON.serialize(
                    buildSourceData(
                        context
                    )
                )
            );

        if (

            String.isBlank(
                promptResponse
            )

        ) {

            return results;

        }

        return parseResults(
            promptResponse,
            questions,
            context
        );

    }

    private static String invokePromptTemplate(

        String userMessage,

        String fieldContextJson,

        String existingValuesJson,

        String applicantKnowledge

    ) {

        Map<String, ConnectApi.WrappedValue> inputParams =
            new Map<String, ConnectApi.WrappedValue>();

        putInputParam(
            inputParams,
            'Input:userMessage',
            userMessage
        );
        putInputParam(
            inputParams,
            'Input:fieldContextJson',
            String.isBlank(fieldContextJson)
                ? '[]'
                : fieldContextJson
        );
        putInputParam(
            inputParams,
            'Input:existingValuesJson',
            String.isBlank(existingValuesJson)
                ? '{}'
                : existingValuesJson
        );
        putInputParam(
            inputParams,
            'Input:applicantKnowledge',
            String.isBlank(applicantKnowledge)
                ? ''
                : applicantKnowledge
        );

        ConnectApi.EinsteinPromptTemplateGenerationsInput input =
            new ConnectApi.EinsteinPromptTemplateGenerationsInput();

        input.isPreview =
            false;

        input.inputParams =
            inputParams;

        input.additionalConfig =
            new ConnectApi.EinsteinLlmAdditionalConfigInput();

        input.additionalConfig.applicationName =
            'PromptBuilderPreview';

        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation output =
            ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                PROMPT_TEMPLATE_API_NAME,
                input
            );

        if (

            output == null ||

            output.generations == null ||

            output.generations.isEmpty()

        ) {

            return null;

        }

        return output.generations[0].text;

    }

    private static void putInputParam(
        Map<String, ConnectApi.WrappedValue> inputParams,
        String key,
        String value
    ) {
        ConnectApi.WrappedValue wrappedValue =
            new ConnectApi.WrappedValue();

        wrappedValue.value =
            value;

        inputParams.put(
            key,
            wrappedValue
        );
    }

    private static List<Object> buildFieldContext(

        List<UserDataDiscoveryService.FormQuestion> questions

    ) {

        List<Object> questionPayload =
            new List<Object>();

        for (

            UserDataDiscoveryService.FormQuestion question
            : questions

        ) {

            if (

                question == null ||

                String.isBlank(
                    question.questionId
                )

            ) {

                continue;

            }

            questionPayload.add(
                new Map<String, Object>{
                    'questionId' =>
                        question.questionId,
                    'label' =>
                        question.questionText,
                    'type' =>
                        question.questionType,
                    'options' =>
                        parseOptions(
                            question.picklistValues
                        )
                }
            );

        }

        return questionPayload;

    }

    private static Map<String, Object> buildSourceData(

        UserDataDiscoveryService.DiscoveryContext context

    ) {

        if (context == null) {
            return new Map<String, Object>();
        }

        return new Map<String, Object>{
            'applicantKnowledge' =>
                context.con == null
                    ? null
                    : context.con.Applicant_Knowledge__c,
            'user' =>
                context.usr == null
                    ? null
                    : new Map<String, Object>{
                        'firstName' => context.usr.FirstName,
                        'lastName' => context.usr.LastName,
                        'email' => context.usr.Email,
                        'phone' => context.usr.Phone,
                        'street' => context.usr.Street,
                        'city' => context.usr.City,
                        'state' => context.usr.State,
                        'postalCode' => context.usr.PostalCode,
                        'country' => context.usr.Country
                    },
            'contact' =>
                context.con == null
                    ? null
                    : new Map<String, Object>{
                        'birthdate' => context.con.Birthdate,
                        'phone' => context.con.Phone,
                        'mobilePhone' => context.con.MobilePhone,
                        'gender' => context.con.Gender__c,
                        'citizenshipStatus' =>
                            context.con.Citizenship_Status__c,
                        'languages' => context.con.Languages__c,
                        'mailingStreet' => context.con.MailingStreet,
                        'mailingCity' => context.con.MailingCity,
                        'mailingState' => context.con.MailingState,
                        'mailingPostalCode' =>
                            context.con.MailingPostalCode,
                        'mailingCountry' => context.con.MailingCountry
                    }
        };

    }

    private static Map<String, UserDataDiscoveryService.DataDiscoveryResult>
    parseResults(

        String responseText,

        List<UserDataDiscoveryService.FormQuestion> questions,

        UserDataDiscoveryService.DiscoveryContext context

    ) {

        Map<String, UserDataDiscoveryService.DataDiscoveryResult> results =
            new Map<String, UserDataDiscoveryService.DataDiscoveryResult>();

        Map<String, Object> parsed =
            parseJsonObject(
                responseText
            );

        if (

            parsed == null ||

            parsed.isEmpty()

        ) {

            return results;

        }

        List<Object> answers =
            firstListValue(
                parsed,
                new List<String>{
                    'answers',
                    'fields',
                    'filledFields',
                    'fieldUpdates',
                    'results'
                }
            );

        if (

            answers == null

        ) {

            answers =
                buildSingleAnswerList(
                    parsed
                );

        }

        if (

            answers == null ||

            answers.isEmpty()

        ) {

            return results;

        }

        Map<String, UserDataDiscoveryService.FormQuestion> questionById =
            new Map<String, UserDataDiscoveryService.FormQuestion>();

        for (

            UserDataDiscoveryService.FormQuestion question
            : questions

        ) {

            if (

                question != null &&

                !String.isBlank(
                    question.questionId
                )

            ) {

                questionById.put(
                    question.questionId,
                    question
                );

            }

        }

        for (

            Object rawAnswer
            : answers

        ) {

            Map<String, Object> answer =
                (Map<String, Object>) rawAnswer;

            String questionId =
                firstStringValue(
                    answer,
                    new List<String>{
                        'questionId',
                        'targetQuestionId',
                        'id'
                    }
                );

            if (

                String.isBlank(
                    questionId
                )

            ) {

                questionId =
                    findQuestionIdByLabel(
                        questionById,
                        firstStringValue(
                            answer,
                            new List<String>{
                                'fieldLabel',
                                'targetLabel',
                                'label'
                            }
                        )
                    );

            }

            if (

                String.isBlank(
                    questionId
                ) ||

                !questionById.containsKey(
                    questionId
                )

            ) {

                continue;

            }

            String value =
                firstStringValue(
                    answer,
                    new List<String>{
                        'value',
                        'newValue',
                        'answer',
                        'recommendedValue',
                        'fieldValue',
                        'extractedValue'
                    }
                );

            String validatedValue =
                validateValue(
                    questionById.get(
                        questionId
                    ),
                    value
                );

            if (

                String.isBlank(
                    validatedValue
                )

            ) {

                continue;

            }

            UserDataDiscoveryService.DataDiscoveryResult result =
                new UserDataDiscoveryService.DataDiscoveryResult();

            result.questionId =
                questionId;

            result.recommendedValue =
                validatedValue;

            result.bestMatchConfidence =
                toDecimal(
                    answer.get(
                        'confidence'
                    ),
                    0.9
                );

            result.reasoning =
                'Einstein Prompt Builder extraction: ' +
                String.valueOf(
                    answer.get(
                        'reason'
                    )
                );

            result.sourceFields.addAll(
                parseSourceFields(
                    answer.get(
                        'sourceFields'
                    )
                )
            );

            if (

                result.sourceFields.isEmpty()

            ) {

                result.sourceFields.add(
                    'Einstein Prompt Builder'
                );

            }

            results.put(
                questionId,
                result
            );

        }

        return results;

    }

    private static Map<String, Object> parseJsonObject(
        String value
    ) {
        if (String.isBlank(value)) {
            return null;
        }

        String jsonText =
            value.trim();

        Integer startIndex =
            jsonText.indexOf('{');

        Integer endIndex =
            jsonText.lastIndexOf('}');

        if (
            startIndex < 0 ||
            endIndex < startIndex
        ) {
            return null;
        }

        jsonText =
            jsonText.substring(
                startIndex,
                endIndex + 1
            );

        try {
            return (Map<String, Object>) JSON.deserializeUntyped(
                jsonText
            );
        }

        catch (Exception e) {
            return null;
        }
    }

    private static List<Object> firstListValue(
        Map<String, Object> values,
        List<String> keys
    ) {
        for (String key : keys) {
            if (
                values.containsKey(key) &&
                values.get(key) instanceof List<Object>
            ) {
                return (List<Object>) values.get(key);
            }
        }

        return null;
    }

    private static List<Object> buildSingleAnswerList(
        Map<String, Object> parsed
    ) {
        String value =
            firstStringValue(
                parsed,
                new List<String>{
                    'value',
                    'newValue',
                    'answer',
                    'recommendedValue',
                    'fieldValue',
                    'extractedValue'
                }
            );

        if (String.isBlank(value)) {
            return null;
        }

        return new List<Object>{
            parsed
        };
    }

    private static String firstStringValue(
        Map<String, Object> values,
        List<String> keys
    ) {
        if (values == null) {
            return null;
        }

        for (String key : keys) {
            if (
                values.containsKey(key) &&
                values.get(key) != null
            ) {
                return String.valueOf(
                    values.get(key)
                );
            }
        }

        return null;
    }

    private static String findQuestionIdByLabel(
        Map<String, UserDataDiscoveryService.FormQuestion> questionById,
        String label
    ) {
        if (
            questionById == null ||
            String.isBlank(label)
        ) {
            return null;
        }

        String normalizedLabel =
            normalizeText(
                label
            );

        for (
            String questionId
            : questionById.keySet()
        ) {
            UserDataDiscoveryService.FormQuestion question =
                questionById.get(
                    questionId
                );

            if (
                question != null &&
                normalizeText(
                    question.questionText
                ) == normalizedLabel
            ) {
                return questionId;
            }
        }

        return null;
    }

    private static String normalizeText(
        String value
    ) {
        return String.isBlank(value)
            ? ''
            : value.toLowerCase().replaceAll(
                '[^a-z0-9]+',
                ' '
            ).trim();
    }

    private static String validateValue(

        UserDataDiscoveryService.FormQuestion question,

        String value

    ) {

        if (

            question == null ||

            String.isBlank(
                value
            )

        ) {

            return null;

        }

        List<String> options =
            parseOptions(
                question.picklistValues
            );

        String type =
            String.isBlank(
                question.questionType
            )
                ? ''
                : question.questionType.toLowerCase();

        if (

            (
                type == 'picklist' ||
                type == 'dropdown' ||
                type == 'radio'
            ) &&

            !options.isEmpty()

        ) {

            for (

                String option
                : options

            ) {

                if (

                    option.equalsIgnoreCase(
                        value.trim()
                    )

                ) {

                    return option;

                }

            }

            return null;

        }

        return value.trim();

    }

    private static List<String> parseOptions(

        String rawOptions

    ) {

        List<String> options =
            new List<String>();

        if (

            String.isBlank(
                rawOptions
            )

        ) {

            return options;

        }

        for (

            String option
            : rawOptions.split(
                '[;,\\n]'
            )

        ) {

            String cleaned =
                option.trim();

            if (

                !String.isBlank(
                    cleaned
                )

            ) {

                options.add(
                    cleaned
                );

            }

        }

        return options;

    }

    private static List<String> parseSourceFields(

        Object rawSourceFields

    ) {

        List<String> sourceFields =
            new List<String>();

        if (

            rawSourceFields instanceof List<Object>

        ) {

            for (

                Object rawSourceField
                : (List<Object>) rawSourceFields

            ) {

                addSourceField(
                    sourceFields,
                    String.valueOf(
                        rawSourceField
                    )
                );

            }

            return sourceFields;

        }

        if (

            rawSourceFields != null

        ) {

            addSourceField(
                sourceFields,
                String.valueOf(
                    rawSourceFields
                )
            );

        }

        return sourceFields;

    }

    private static void addSourceField(

        List<String> sourceFields,

        String sourceField

    ) {

        if (

            String.isBlank(
                sourceField
            )

        ) {

            return;

        }

        String cleanedSourceField =
            sourceField.trim();

        if (

            !sourceFields.contains(
                cleanedSourceField
            )

        ) {

            sourceFields.add(
                cleanedSourceField
            );

        }

    }

    private static Decimal toDecimal(

        Object rawValue,

        Decimal defaultValue

    ) {

        if (

            rawValue == null

        ) {

            return defaultValue;

        }

        try {

            return Decimal.valueOf(
                String.valueOf(
                    rawValue
                )
            );

        }

        catch (Exception e) {

            return defaultValue;

        }

    }

}
