public without sharing class AIFormFillerController {

    public class AgentFillRequest {
        @InvocableVariable(
            label='Command'
            description='Optional user command, such as fill all fields or fill missing fields.'
        )
        public String command;
    }

    public class AgentFillResponse {
        @InvocableVariable(
            label='Result JSON'
            description='JSON response from the existing AI form fill controller.'
        )
        public String resultJson;
    }

    @InvocableMethod(
        label='Fill Form Fields With AI'
        description='Runs the existing AI form autofill flow and returns the filled field results as JSON.'
    )
    public static List<AgentFillResponse>
    fillFormFieldsForAgent(
        List<AgentFillRequest> requests
    ) {
        List<AgentFillResponse> responses =
            new List<AgentFillResponse>();

        Integer requestCount =
            requests == null || requests.isEmpty()
                ? 1
                : requests.size();

        for (
            Integer i = 0;
            i < requestCount;
            i++
        ) {
            AgentFillResponse response =
                new AgentFillResponse();

            response.resultJson =
                JSON.serialize(
                    fillFormWithAI()
                );

            responses.add(
                response
            );
        }

        return responses;
    }

    @AuraEnabled
    public static Map<String, Object>
    fillFormWithAI() {

        try {

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
                    Picklist_Values__c,
                    Display_Order__c

                FROM Form_Configuration_c__mdt

                ORDER BY Display_Order__c ASC

            ]

        ) {

            if (

                String.isBlank(
                    q.Question_Id__c
                )

            ) {

                System.debug(
                    'Skipping form configuration with blank Question_Id__c: ' +
                    q.MasterLabel
                );

                continue;

            }

            UserDataDiscoveryService.FormQuestion question =
                new UserDataDiscoveryService.FormQuestion();

            question.questionId =
                q.Question_Id__c;

            question.questionText =
                q.MasterLabel;

            question.questionType =
                q.Question_Type__c;

            question.picklistValues =
                q.Picklist_Values__c;

            questions.add(question);

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

        /*
         * RUN EINSTEIN PROMPT BUILDER SEMANTIC EXTRACTION FIRST
         */

        Map<String, UserDataDiscoveryService.DataDiscoveryResult>
            einsteinPromptResults =
                new Map<String, UserDataDiscoveryService.DataDiscoveryResult>();

        try {

            einsteinPromptResults =
                EinsteinPromptExtractionService.extractAnswers(
                    UserInfo.getUserId(),
                    questions
                );

        }

        catch (Exception e) {

            System.debug(
                LoggingLevel.WARN,
                'Einstein Prompt Builder extraction skipped: ' +
                e.getMessage()
            );

        }

        Map<String, UserDataDiscoveryService.DataDiscoveryResult>
            discoveryResults =
                new Map<String, UserDataDiscoveryService.DataDiscoveryResult>(
                    einsteinPromptResults
                );

        /*
         * RUN CLASS-BASED DISCOVERY ONLY AS FALLBACK
         */

        Map<String, UserDataDiscoveryService.DataDiscoveryResult>
            userDiscoveryResults =
                UserDataDiscoveryService.discoverDataForForm(
                    UserInfo.getUserId(),
                    questions
                );

        for (

            String questionId
            : userDiscoveryResults.keySet()

        ) {

            UserDataDiscoveryService.DataDiscoveryResult existingResult =
                discoveryResults.get(
                    questionId
                );

            Boolean existingHasValue =
                existingResult != null &&

                (

                    !String.isBlank(
                        existingResult.recommendedValue
                    ) ||

                    existingResult.clearValue == true

                );

            if (

                !existingHasValue

            ) {

                discoveryResults.put(
                    questionId,
                    userDiscoveryResults.get(
                        questionId
                    )
                );

            }

            else {

                UserDataDiscoveryService.DataDiscoveryResult fallbackResult =
                    userDiscoveryResults.get(
                        questionId
                    );

                if (

                    shouldUseFallbackSourceFields(
                        existingResult,
                        fallbackResult
                    )

                ) {

                    existingResult.sourceFields =
                        new List<String>(
                            fallbackResult.sourceFields
                        );

                    if (

                        !String.isBlank(
                            fallbackResult.reasoning
                        )

                    ) {

                        existingResult.reasoning =
                            String.isBlank(
                                existingResult.reasoning
                            )
                                ? fallbackResult.reasoning
                                : existingResult.reasoning +
                                    ' | Source fields from fallback synthesis: ' +
                                    fallbackResult.reasoning;

                    }

                }

            }

        }

        /*
         * RUN OPENAI SEMANTIC EXTRACTION AS LAST FALLBACK AND COMPARISON
         */

        Map<String, UserDataDiscoveryService.DataDiscoveryResult>
            openAiResults =
                new Map<String, UserDataDiscoveryService.DataDiscoveryResult>();

        try {

            openAiResults =
                AIQuestionExtractionService.extractAnswers(
                    UserInfo.getUserId(),
                    questions
                );

        }

        catch (Exception e) {

            System.debug(
                LoggingLevel.WARN,
                'OpenAI semantic extraction skipped: ' +
                e.getMessage()
            );

        }

        for (

            String questionId
            : openAiResults.keySet()

        ) {

            UserDataDiscoveryService.DataDiscoveryResult existingResult =
                discoveryResults.get(
                    questionId
                );

            UserDataDiscoveryService.FormQuestion question =
                questionById.get(
                    questionId
                );

            UserDataDiscoveryService.DataDiscoveryResult openAiResult =
                openAiResults.get(
                    questionId
                );

            if (

                isEssayQuestion(
                    question
                ) &&

                (

                    openAiResult == null ||

                    !isMeaningfulEssayValue(
                        openAiResult.recommendedValue
                    )

                )

            ) {

                continue;

            }

            Boolean existingHasValue =
                existingResult != null &&

                (

                    !String.isBlank(
                        existingResult.recommendedValue
                    ) ||

                    existingResult.clearValue == true

                );

            if (

                !existingHasValue

            ) {

                discoveryResults.put(
                    questionId,
                    openAiResult
                );

            }

        }

        applyApplicantKnowledgeChoiceCorrections(
            discoveryResults,
            questions,
            UserInfo.getUserId()
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

                (

                    !String.isBlank(
                        result.recommendedValue
                    ) ||

                    result.clearValue == true

                )

            ) {

                filledFields.put(

                    questionId,

                    new Map<String, Object>{

                        'value' =>
                            result.clearValue == true
                                ? ''
                                : result.recommendedValue,

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
            'aiComparisonResults',
            buildAiComparisonResults(
                questions,
                userDiscoveryResults,
                openAiResults,
                einsteinPromptResults,
                discoveryResults
            )
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

        catch (Exception e) {

            System.debug(
                LoggingLevel.ERROR,
                'AIFormFillerController.fillFormWithAI failed: ' +
                e.getMessage() +
                '\n' +
                e.getStackTraceString()
            );

            throw new AuraHandledException(
                'AI form fill failed: ' +
                e.getMessage()
            );

        }

    }

    private static Map<String, Object> buildAiComparisonResults(

        List<UserDataDiscoveryService.FormQuestion> questions,

        Map<String, UserDataDiscoveryService.DataDiscoveryResult>
            userDiscoveryResults,

        Map<String, UserDataDiscoveryService.DataDiscoveryResult>
            openAiResults,

        Map<String, UserDataDiscoveryService.DataDiscoveryResult>
            einsteinPromptResults,

        Map<String, UserDataDiscoveryService.DataDiscoveryResult>
            finalResults

    ) {

        Map<String, Object> comparison =
            new Map<String, Object>();

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

            String questionId =
                question.questionId;

            Map<String, Object> row =
                new Map<String, Object>{
                    'label' =>
                        question.questionText,
                    'userDiscovery' =>
                        summarizeProviderResult(
                            userDiscoveryResults.get(
                                questionId
                            )
                        ),
                    'openAI' =>
                        summarizeProviderResult(
                            openAiResults.get(
                                questionId
                            )
                        ),
                    'einsteinPromptBuilder' =>
                        summarizeProviderResult(
                            einsteinPromptResults.get(
                                questionId
                            )
                        ),
                    'selected' =>
                        summarizeProviderResult(
                            finalResults.get(
                                questionId
                            )
                        )
                };

            comparison.put(
                questionId,
                row
            );

            System.debug(
                LoggingLevel.INFO,
                'AI_COMPARE -> QUESTION: ' +
                question.questionText +
                ' | USERDISCOVERY: ' +
                summarizeValue(
                    userDiscoveryResults.get(
                        questionId
                    )
                ) +
                ' | OPENAI: ' +
                summarizeValue(
                    openAiResults.get(
                        questionId
                    )
                ) +
                ' | EINSTEIN: ' +
                summarizeValue(
                    einsteinPromptResults.get(
                        questionId
                    )
                ) +
                ' | SELECTED: ' +
                summarizeValue(
                    finalResults.get(
                        questionId
                    )
                )
            );

        }

        return comparison;

    }

    private static Map<String, Object> summarizeProviderResult(

        UserDataDiscoveryService.DataDiscoveryResult result

    ) {

        if (

            result == null

        ) {

            return new Map<String, Object>{
                'value' => null,
                'confidence' => null,
                'reasoning' => null,
                'sourceFields' => new List<String>()
            };

        }

        return new Map<String, Object>{
            'value' =>
                result.clearValue == true
                    ? ''
                    : result.recommendedValue,
            'confidence' =>
                result.bestMatchConfidence,
            'reasoning' =>
                result.reasoning,
            'sourceFields' =>
                result.sourceFields == null
                    ? new List<String>()
                    : result.sourceFields
        };

    }

    private static String summarizeValue(

        UserDataDiscoveryService.DataDiscoveryResult result

    ) {

        if (

            result == null

        ) {

            return 'null';

        }

        return result.clearValue == true
            ? '[CLEAR]'
            : result.recommendedValue;

    }

    private static Boolean shouldOpenAiReplaceExistingValue(

        UserDataDiscoveryService.FormQuestion question,

        UserDataDiscoveryService.DataDiscoveryResult existingResult,

        UserDataDiscoveryService.DataDiscoveryResult openAiResult

    ) {

        if (

            existingResult == null ||

            openAiResult == null ||

            String.isBlank(
                openAiResult.recommendedValue
            )

        ) {

            return false;

        }

        if (

            isEssayQuestion(
                question
            )

        ) {

            if (

                isMeaningfulEssayValue(
                    existingResult.recommendedValue
                )

            ) {

                return false;

            }

            if (

                !isMeaningfulEssayValue(
                    openAiResult.recommendedValue
                )

            ) {

                return false;

            }

        }

        Decimal openAiConfidence =
            openAiResult.bestMatchConfidence == null
                ? 0
                : openAiResult.bestMatchConfidence;

        if (

            openAiConfidence < 0.85

        ) {

            return false;

        }

        Decimal existingConfidence =
            existingResult.bestMatchConfidence == null
                ? 0
                : existingResult.bestMatchConfidence;

        String existingReasoning =
            String.isBlank(
                existingResult.reasoning
            )
                ? ''
                : existingResult.reasoning.toLowerCase();

        if (

            existingReasoning.contains(
                'synthesized'
            ) ||

            existingReasoning.contains(
                'synthesis'
            )

        ) {

            return false;

        }

        Boolean existingIsFallback =
            existingReasoning.contains(
                'generic'
            ) ||

            existingReasoning.contains(
                'semantic match'
            );

        return existingIsFallback ||

        existingConfidence < 0.9;

    }

    private static Boolean isEssayQuestion(

        UserDataDiscoveryService.FormQuestion question

    ) {

        if (

            question == null

        ) {

            return false;

        }

        String label =
            normalize(
                question.questionText
            );

        return label.contains(
            'statement of purpose'
        ) ||

        label.contains(
            'purpose statement'
        ) ||

        label.contains(
            'personal statement'
        ) ||

        label.contains(
            'personal essay'
        );

    }

    private static Boolean isMeaningfulEssayValue(

        String value

    ) {

        if (

            String.isBlank(
                value
            )

        ) {

            return false;

        }

        String normalizedValue =
            normalize(
                value
            );

        if (

            normalizedValue.length() < 80

        ) {

            return false;

        }

        Integer wordCount =
            normalizedValue.split(
                '\\s+'
            ).size();

        return wordCount >= 12;

    }

    private static void applyApplicantKnowledgeChoiceCorrections(

        Map<String, UserDataDiscoveryService.DataDiscoveryResult> results,

        List<UserDataDiscoveryService.FormQuestion> questions,

        Id userId

    ) {

        if (

            results == null ||

            questions == null ||

            questions.isEmpty()

        ) {

            return;

        }

        UserDataDiscoveryService.DiscoveryContext context =
            UserDataDiscoveryService.loadDiscoveryContext(
                userId
            );

        if (

            context == null ||

            context.con == null ||

            String.isBlank(
                context.con.Applicant_Knowledge__c
            )

        ) {

            return;

        }

        String knowledge =
            context.con.Applicant_Knowledge__c;

        for (

            UserDataDiscoveryService.FormQuestion question
            : questions

        ) {

            if (

                question == null ||

                String.isBlank(
                    question.questionId
                ) ||

                !isChoiceQuestion(
                    question
                )

            ) {

                continue;

            }

            String correctedValue =
                extractExplicitChoiceFromKnowledge(
                    question,
                    knowledge
                );

            if (

                String.isBlank(
                    correctedValue
                )

            ) {

                continue;

            }

            UserDataDiscoveryService.DataDiscoveryResult result =
                results.containsKey(
                    question.questionId
                )
                    ? results.get(
                        question.questionId
                    )
                    : new UserDataDiscoveryService.DataDiscoveryResult();

            if (

                result == null

            ) {

                result =
                    new UserDataDiscoveryService.DataDiscoveryResult();

            }

            if (

                result.recommendedValue == correctedValue

            ) {

                System.debug(
                    LoggingLevel.INFO,
                    'AI choice correction kept existing value -> QUESTION: ' +
                    question.questionText +
                    ' | VALUE: ' +
                    correctedValue
                );

                continue;

            }

            result.questionId =
                question.questionId;

            result.recommendedValue =
                correctedValue;

            result.clearValue =
                false;

            result.bestMatchConfidence =
                0.97;

            result.reasoning =
                'Applicant knowledge explicit choice correction';

            if (

                result.sourceFields == null

            ) {

                result.sourceFields =
                    new List<String>();

            }

            result.sourceFields.add(
                'Applicant_Knowledge__c explicit choice'
            );

            System.debug(
                LoggingLevel.INFO,
                'AI choice correction replaced value -> QUESTION: ' +
                question.questionText +
                ' | VALUE: ' +
                correctedValue
            );

            results.put(
                question.questionId,
                result
            );

        }

    }

    private static String extractExplicitChoiceFromKnowledge(

        UserDataDiscoveryService.FormQuestion question,

        String knowledge

    ) {

        List<String> options =
            parseOptions(
                question.picklistValues
            );

        if (

            options.isEmpty() ||

            String.isBlank(
                knowledge
            ) ||

            !isAcademicChoiceLabel(
                question.questionText
            )

        ) {

            return null;

        }

        List<Pattern> explicitPatterns =
            new List<Pattern>{
                Pattern.compile(
                    '(?i)\\bpreferred\\s+(?:specialization|concentration|track|focus\\s+area|major|course)\\s+(?:is|as|:|=)\\s*([^.;\\n]+)'
                ),
                Pattern.compile(
                    '(?i)\\b(?:specialization|concentration|track|focus\\s+area|major|course)\\s+(?:is|as|:|=)\\s*([^.;\\n]+)'
                )
            };

        for (

            Pattern explicitPattern
            : explicitPatterns

        ) {

            Matcher matcher =
                explicitPattern.matcher(
                    knowledge
                );

            if (

                matcher.find()

            ) {

                String matchedOption =
                    matchOptionFromList(
                        matcher.group(1),
                        options
                    );

                if (

                    !String.isBlank(
                        matchedOption
                    )

                ) {

                    return matchedOption;

                }

            }

        }

        return null;

    }

    private static Boolean isAcademicChoiceLabel(

        String label

    ) {

        String normalizedLabel =
            normalize(
                label
            );

        return normalizedLabel.contains(
            'specialization'
        ) ||

        normalizedLabel.contains(
            'concentration'
        ) ||

        normalizedLabel.contains(
            'track'
        ) ||

        normalizedLabel.contains(
            'focus area'
        ) ||

        normalizedLabel.contains(
            'major'
        ) ||

        normalizedLabel.contains(
            'course'
        ) ||

        normalizedLabel.contains(
            'area of study'
        ) ||

        normalizedLabel.contains(
            'field of study'
        ) ||

        normalizedLabel.contains(
            'subject'
        ) ||

        normalizedLabel.contains(
            'discipline'
        );

    }

    private static Boolean isChoiceQuestion(

        UserDataDiscoveryService.FormQuestion question

    ) {

        if (

            question == null

        ) {

            return false;

        }

        String type =
            String.isBlank(
                question.questionType
            )
                ? ''
                : question.questionType.toLowerCase();

        return type == 'picklist' ||

        type == 'dropdown' ||

        type == 'radio' ||

        !String.isBlank(
            question.picklistValues
        );

    }

    private static String matchOptionFromList(

        String value,

        List<String> options

    ) {

        if (

            String.isBlank(
                value
            ) ||

            options == null ||

            options.isEmpty()

        ) {

            return null;

        }

        String normalizedValue =
            normalize(
                value
            );

        for (

            String option
            : options

        ) {

            String normalizedOption =
                normalize(
                    option
                );

            if (

                normalizedValue == normalizedOption ||

                normalizedValue.contains(
                    normalizedOption
                ) ||

                normalizedOption.contains(
                    normalizedValue
                )

            ) {

                return option;

            }

        }

        return null;

    }

    private static List<String> parseOptions(

        String picklistValues

    ) {

        List<String> options =
            new List<String>();

        if (

            String.isBlank(
                picklistValues
            )

        ) {

            return options;

        }

        for (

            String rawOption
            : picklistValues.split(
                '[,;\\n]'
            )

        ) {

            String option =
                rawOption.trim();

            if (

                !String.isBlank(
                    option
                )

            ) {

                options.add(
                    option
                );

            }

        }

        return options;

    }

    private static String normalize(

        String value

    ) {

        return String.isBlank(
            value
        )
            ? ''
            : value.toLowerCase()
                .replaceAll(
                    '[^a-z0-9]+',
                    ' '
                )
                .replaceAll(
                    '\\s+',
                    ' '
                )
                .trim();

    }

    private static Boolean shouldUseFallbackSourceFields(

        UserDataDiscoveryService.DataDiscoveryResult existingResult,

        UserDataDiscoveryService.DataDiscoveryResult fallbackResult

    ) {

        if (

            existingResult == null ||
            fallbackResult == null ||
            fallbackResult.sourceFields == null ||
            countRealSourceFields(
                fallbackResult.sourceFields
            ) < 2

        ) {

            return false;

        }

        return existingResult.sourceFields == null ||
            countRealSourceFields(
                existingResult.sourceFields
            ) < 2;

    }

    private static Integer countRealSourceFields(

        List<String> sourceFields

    ) {

        Integer count =
            0;

        Set<String> seenSources =
            new Set<String>();

        if (

            sourceFields == null

        ) {

            return count;

        }

        for (

            String sourceField
            : sourceFields

        ) {

            String normalizedSource =
                normalizeSourceField(
                    sourceField
                );

            if (

                !String.isBlank(
                    normalizedSource
                ) &&
                !isGenericSourceField(
                    normalizedSource
                ) &&
                !seenSources.contains(
                    normalizedSource
                )

            ) {

                seenSources.add(
                    normalizedSource
                );

                count++;

            }

        }

        return count;

    }

    private static String normalizeSourceField(

        String sourceField

    ) {

        return String.isBlank(
            sourceField
        )
            ? ''
            : sourceField
                .replace(
                    '[',
                    ''
                )
                .replace(
                    ']',
                    ''
                )
                .replace(
                    '"',
                    ''
                )
                .trim()
                .toLowerCase();

    }

    private static Boolean isGenericSourceField(

        String sourceField

    ) {

        String normalizedSource =
            normalizeSourceField(
                sourceField
            );

        return normalizedSource == 'prompt builder' ||
            normalizedSource == 'einstein prompt builder' ||
            normalizedSource == 'applicant knowledge' ||
            normalizedSource == 'ai' ||
            normalizedSource == 'chat prompt' ||
            normalizedSource.contains(
                'prompt builder'
            ) ||
            normalizedSource.contains(
                'openai semantic extraction'
            );

    }

}
