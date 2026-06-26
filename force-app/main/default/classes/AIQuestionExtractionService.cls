public without sharing class AIQuestionExtractionService {

    private static final String ENDPOINT =
        'callout:OpenAI_API/v1/responses';

    private static final String MODEL =
        'gpt-5.2';

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

        HttpRequest request =
            new HttpRequest();

        request.setEndpoint(
            ENDPOINT
        );

        request.setMethod(
            'POST'
        );

        request.setHeader(
            'Content-Type',
            'application/json'
        );

        request.setTimeout(
            120000
        );

        request.setBody(
            JSON.serialize(
                buildRequestBody(
                    questions,
                    context
                )
            )
        );

        HttpResponse response =
            new Http().send(
                request
            );

        if (

            response.getStatusCode() < 200 ||

            response.getStatusCode() >= 300

        ) {

            System.debug(
                LoggingLevel.WARN,
                'OpenAI extraction failed: ' +
                response.getStatusCode() +
                ' ' +
                response.getBody()
            );

            return results;

        }

        String responseText =
            extractResponseText(
                response.getBody()
            );

        if (

            String.isBlank(
                responseText
            )

        ) {

            return results;

        }

        Map<String, Object> parsed =
            (Map<String, Object>) JSON.deserializeUntyped(
                responseText
            );

        List<Object> answers =
            (List<Object>) parsed.get(
                'answers'
            );

        if (

            answers == null

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
                (String) answer.get(
                    'questionId'
                );

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

            Object rawValue =
                answer.get(
                    'value'
                );

            String value =
                rawValue == null
                    ? null
                    : String.valueOf(
                        rawValue
                    );

            UserDataDiscoveryService.FormQuestion question =
                questionById.get(
                    questionId
                );

            value =
                preferExplicitChoiceFromKnowledge(
                    question,
                    value,
                    context
                );

            String validatedValue =
                validateValue(
                    question,
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
                'OpenAI semantic extraction: ' +
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
                    'OpenAI semantic extraction'
                );

            }

            results.put(
                questionId,
                result
            );

        }

        return results;

    }

    private static List<String> parseSourceFields(

        Object rawSourceFields

    ) {

        List<String> sourceFields =
            new List<String>();

        if (

            rawSourceFields == null

        ) {

            return sourceFields;

        }

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

        addSourceField(
            sourceFields,
            String.valueOf(
                rawSourceFields
            )
        );

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

    private static Map<String, Object> buildRequestBody(

        List<UserDataDiscoveryService.FormQuestion> questions,

        UserDataDiscoveryService.DiscoveryContext context

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

        Map<String, Object> sourceData =
            new Map<String, Object>{
                'applicantKnowledge' =>
                    context.con == null
                        ? null
                        : UserDataDiscoveryService.getContactText(
                            context.con,
                            'Applicant_Knowledge__c'
                        ),
                'user' =>
                    new Map<String, Object>{
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
                            'gender' =>
                                UserDataDiscoveryService.getContactText(
                                    context.con,
                                    'Gender__c'
                                ),
                            'citizenshipStatus' =>
                                UserDataDiscoveryService.getContactText(
                                    context.con,
                                    'Citizenship_Status__c'
                                ),
                            'languages' =>
                                UserDataDiscoveryService.getContactText(
                                    context.con,
                                    'Languages__c'
                                ),
                            'mailingStreet' => context.con.MailingStreet,
                            'mailingCity' => context.con.MailingCity,
                            'mailingState' => context.con.MailingState,
                            'mailingPostalCode' =>
                                context.con.MailingPostalCode,
                            'mailingCountry' => context.con.MailingCountry
                        }
            };

        String instructions =
            'Extract application form answers. ' +
            'Use only the supplied sourceData. ' +
            'Understand each question label semantically. ' +
            'Question labels may have been renamed from their original meaning. ' +
            'For picklist and radio questions, use the available options as strong context for what the question is asking. ' +
            'If a label is broad or ambiguous, such as course, area, choice, status, or plan, infer the intended field from both the label and its options. ' +
            'Choose an option only when sourceData clearly supports that option. ' +
            'Do not choose a default or example option. Choose the option whose value or meaning is stated in sourceData. ' +
            'If sourceData supports a different option later, return that different supported option. ' +
            'For academic choice fields, prefer explicit statements such as preferred specialization, concentration, track, focus area, major, or course over the broader program or degree name. ' +
            'Do not choose an option just because it appears in the program name unless the question is asking for the program or degree. ' +
            'For Statement of Purpose, Personal Statement, and other essay questions, use only applicantKnowledge; never answer from user or contact address fields. ' +
            'Essay answers must be complete meaningful sentences, not a state, country, city, phone, email, date, or short field value. ' +
            'For contact information or contact details questions, include only communication details such as email, phone, or mobile phone. Do not include street, city, state, postal code, country, or full address unless the label explicitly asks for address. ' +
            'For full address questions, combine only street, city, state, postal code, and country; do not include phone or email. ' +
            'If the question is unrelated to sourceData, return null. ' +
            'Do not invent or infer unsupported values. ' +
            'For picklist or radio questions, return exactly one supplied option. ' +
            'For date questions, return YYYY-MM-DD. ' +
            'For number questions, return only the number. ' +
            'For every non-null answer, include sourceFields with the exact sourceData fields used, such as Applicant_Knowledge__c, User.Email, User.Phone, Contact.MobilePhone, Contact.MailingStreet, Contact.MailingCity, Contact.MailingState, Contact.MailingPostalCode, or Contact.MailingCountry. ' +
            'If the answer is based on applicantKnowledge text, use Applicant_Knowledge__c as the source field. ' +
            'Return JSON that matches the schema.';

        Map<String, Object> userPayload =
            new Map<String, Object>{
                'questions' =>
                    questionPayload,
                'sourceData' =>
                    sourceData
            };

        return new Map<String, Object>{
            'model' =>
                MODEL,
            'input' =>
                new List<Object>{
                    new Map<String, Object>{
                        'role' => 'developer',
                        'content' => instructions
                    },
                    new Map<String, Object>{
                        'role' => 'user',
                        'content' => JSON.serialize(
                            userPayload
                        )
                    }
                },
            'text' =>
                new Map<String, Object>{
                    'format' =>
                        buildJsonSchema()
                }
        };

    }

    private static Map<String, Object> buildJsonSchema() {

        return new Map<String, Object>{
            'type' =>
                'json_schema',
            'name' =>
                'form_extraction',
            'strict' =>
                true,
            'schema' =>
                new Map<String, Object>{
                    'type' => 'object',
                    'properties' =>
                        new Map<String, Object>{
                            'answers' =>
                                new Map<String, Object>{
                                    'type' => 'array',
                                    'items' =>
                                        new Map<String, Object>{
                                            'type' => 'object',
                                            'properties' =>
                                                new Map<String, Object>{
                                                    'questionId' =>
                                                        new Map<String, Object>{
                                                            'type' => 'string'
                                                        },
                                                    'value' =>
                                                        new Map<String, Object>{
                                                            'type' =>
                                                                new List<Object>{
                                                                    'string',
                                                                    'null'
                                                                }
                                                        },
                                                    'confidence' =>
                                                        new Map<String, Object>{
                                                            'type' => 'number'
                                                        },
                                                    'reason' =>
                                                        new Map<String, Object>{
                                                            'type' => 'string'
                                                        },
                                                    'sourceFields' =>
                                                        new Map<String, Object>{
                                                            'type' => 'array',
                                                            'items' =>
                                                                new Map<String, Object>{
                                                                    'type' =>
                                                                        'string'
                                                                }
                                                        }
                                                },
                                            'required' =>
                                                new List<Object>{
                                                    'questionId',
                                                    'value',
                                                    'confidence',
                                                    'reason',
                                                    'sourceFields'
                                                },
                                            'additionalProperties' =>
                                                false
                                        }
                                }
                        },
                    'required' =>
                        new List<Object>{
                            'answers'
                        },
                    'additionalProperties' =>
                        false
                }
        };

    }

    private static String extractResponseText(

        String responseBody

    ) {

        Map<String, Object> parsed =
            (Map<String, Object>) JSON.deserializeUntyped(
                responseBody
            );

        if (

            parsed.containsKey(
                'output_text'
            )

        ) {

            return (String) parsed.get(
                'output_text'
            );

        }

        List<Object> output =
            (List<Object>) parsed.get(
                'output'
            );

        if (

            output == null

        ) {

            return null;

        }

        for (

            Object rawItem
            : output

        ) {

            Map<String, Object> item =
                (Map<String, Object>) rawItem;

            List<Object> content =
                (List<Object>) item.get(
                    'content'
                );

            if (

                content == null

            ) {

                continue;

            }

            for (

                Object rawContent
                : content

            ) {

                Map<String, Object> contentItem =
                    (Map<String, Object>) rawContent;

                if (

                    contentItem.containsKey(
                        'text'
                    )

                ) {

                    return (String) contentItem.get(
                        'text'
                    );

                }

            }

        }

        return null;

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

        String trimmedValue =
            value.trim();

        String type =
            String.isBlank(
                question.questionType
            )
                ? ''
                : question.questionType.toLowerCase();

        if (

            type == 'picklist' ||

            type == 'dropdown' ||

            type == 'radio'

        ) {

            return matchOption(
                trimmedValue,
                question.picklistValues
            );

        }

        if (

            type == 'date' ||

            safeLower(
                question.questionText
            ).contains(
                'date'
            )

        ) {

            return validateDate(
                trimmedValue
            );

        }

        if (

            type == 'number'

        ) {

            return validateNumber(
                trimmedValue
            );

        }

        if (

            type == 'checkbox'

        ) {

            String lower =
                safeLower(
                    trimmedValue
                );

            if (

                lower == 'true' ||

                lower == 'false'

            ) {

                return lower;

            }

            return null;

        }

        if (

            isEssayQuestion(
                question
            ) &&

            !isMeaningfulEssayValue(
                trimmedValue
            )

        ) {

            return null;

        }

        return trimmedValue;

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

    private static String preferExplicitChoiceFromKnowledge(

        UserDataDiscoveryService.FormQuestion question,

        String currentValue,

        UserDataDiscoveryService.DiscoveryContext context

    ) {

        if (

            question == null ||

            context == null ||

            context.con == null ||

            String.isBlank(
                UserDataDiscoveryService.getContactText(
                    context.con,
                    'Applicant_Knowledge__c'
                )
            ) ||

            !isChoiceQuestion(
                question
            )

        ) {

            return currentValue;

        }

        List<String> options =
            parseOptions(
                question.picklistValues
            );

        if (

            options.isEmpty()

        ) {

            return currentValue;

        }

        String knowledge =
            UserDataDiscoveryService.getContactText(
                context.con,
                'Applicant_Knowledge__c'
            );

        List<Pattern> explicitChoicePatterns =
            new List<Pattern>{
                Pattern.compile(
                    '(?i)\\bpreferred\\s+(?:specialization|concentration|track|focus area|major|course)\\s+(?:is|as|:|=)\\s*([^.;\\n]+)'
                ),
                Pattern.compile(
                    '(?i)\\b(?:specialization|concentration|track|focus area|major|course)\\s+(?:is|as|:|=)\\s*([^.;\\n]+)'
                )
            };

        for (

            Pattern explicitChoicePattern
            : explicitChoicePatterns

        ) {

            Matcher matcher =
                explicitChoicePattern.matcher(
                    knowledge
                );

            if (

                matcher.find()

            ) {

                String explicitValue =
                    matcher.group(1);

                String matchedOption =
                    matchOptionFromList(
                        explicitValue,
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

        return currentValue;

    }

    private static String validateDate(

        String value

    ) {

        try {

            Date parsedDate =
                Date.valueOf(
                    value
                );

            return String.valueOf(
                parsedDate
            );

        }

        catch (Exception e) {

            return null;

        }

    }

    private static String validateNumber(

        String value

    ) {

        try {

            Decimal parsedNumber =
                Decimal.valueOf(
                    value
                );

            return String.valueOf(
                parsedNumber
            );

        }

        catch (Exception e) {

            return null;

        }

    }

    private static String matchOption(

        String value,

        String picklistValues

    ) {

        if (

            String.isBlank(
                picklistValues
            )

        ) {

            return null;

        }

        String normalizedValue =
            normalize(
                value
            );

        for (

            String option
            : parseOptions(
                picklistValues
            )

        ) {

            if (

                normalize(
                    option
                ) == normalizedValue

            ) {

                return option;

            }

        }

        return null;

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

    private static Decimal toDecimal(

        Object value,

        Decimal fallbackValue

    ) {

        if (

            value == null

        ) {

            return fallbackValue;

        }

        try {

            return Decimal.valueOf(
                String.valueOf(
                    value
                )
            );

        }

        catch (Exception e) {

            return fallbackValue;

        }

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

    private static String safeLower(

        String value

    ) {

        return String.isBlank(
            value
        )
            ? ''
            : value.toLowerCase();

    }

}
