public without sharing class AgentforceCommandInterpreter {

    /*
     * Set these after the Agent is activated.
     *
     * Keep this service command-only. Do not use it from fillFormWithAI(),
     * because the Agent can call the fill controller as one of its actions.
     */
    private static final String AGENT_API_NAME = 'Application_Assistant';

    private static final String AGENT_ACTION_VERSION = '1.1.0';

    @AuraEnabled
    public static Map<String, Object> interpretCommand(
        String command,
        String sessionId,
        String fieldContextJson
    ) {
        Map<String, Object> response =
            new Map<String, Object>{
                'handled' => false,
                'enabled' => !String.isBlank(AGENT_API_NAME)
            };

        if (String.isBlank(command)) {
            response.put(
                'reason',
                'Blank command.'
            );
            return response;
        }

        if (isFillAllCommand(command)) {
            response.put(
                'reason',
                'Fill-all commands are handled directly by AIFormFillerController to avoid an Agent/controller loop.'
            );
            return response;
        }

        if (String.isBlank(AGENT_API_NAME)) {
            response.put(
                'reason',
                'Agent API name is not configured.'
            );
            return response;
        }

        try {
            String agentMessage =
                buildAgentMessage(
                    command,
                    fieldContextJson
                );

            List<Invocable.Action.Result> results =
                invokeAgent(
                    agentMessage,
                    sessionId,
                    response
                );

            if (results == null || results.isEmpty()) {
                response.put(
                    'reason',
                    'Agent returned no result.'
                );
                return response;
            }

            Invocable.Action.Result result =
                results[0];

            if (!result.isSuccess()) {
                response.put(
                    'reason',
                    'Agent action failed: ' +
                    String.valueOf(
                        result.getErrors()
                    )
                );
                response.put(
                    'errors',
                    String.valueOf(result.getErrors())
                );
                return response;
            }

            Map<String, Object> outputParams =
                result.getOutputParameters();

            response.put(
                'sessionId',
                outputParams == null
                    ? null
                    : outputParams.get('sessionId')
            );

            String agentText =
                getFirstTextOutput(
                    outputParams
                );

            response.put(
                'agentResponse',
                agentText
            );

            Map<String, Object> parsed =
                parseJsonObject(
                    agentText
                );

            if (parsed == null || parsed.isEmpty()) {
                response.put(
                    'reason',
                    'Agent did not return structured command JSON.'
                );
                return response;
            }

            String parsedAction =
                valueAsString(
                    parsed.get('action')
                );

            if (String.isBlank(parsedAction)) {
                response.put(
                    'reason',
                    'Agent response did not include an action.'
                );
                return response;
            }

            if (parsedAction.equalsIgnoreCase('fill_all')) {
                response.put(
                    'reason',
                    'Agent requested fill_all, but fill-all is handled directly by the controller.'
                );
                return response;
            }

            response.putAll(
                parsed
            );

            response.put(
                'handled',
                true
            );

            return response;
        }

        catch (Exception e) {
            response.put(
                'reason',
                e.getTypeName() +
                ': ' +
                e.getMessage()
            );
            response.put(
                'stackTrace',
                e.getStackTraceString()
            );
            return response;
        }
    }

    private static List<Invocable.Action.Result> invokeAgent(
        String agentMessage,
        String sessionId,
        Map<String, Object> response
    ) {
        try {
            response.put(
                'agentInvocationMode',
                'versioned'
            );

            return invokeAgentOnce(
                agentMessage,
                sessionId,
                true
            );
        }

        catch (Exception versionedException) {
            response.put(
                'versionedInvocationError',
                versionedException.getTypeName() +
                ': ' +
                versionedException.getMessage()
            );

            response.put(
                'agentInvocationMode',
                'legacy'
            );

            return invokeAgentOnce(
                agentMessage,
                sessionId,
                false
            );
        }
    }

    private static List<Invocable.Action.Result> invokeAgentOnce(
        String agentMessage,
        String sessionId,
        Boolean useVersionedAction
    ) {
        Invocable.Action action =
            useVersionedAction
                ? Invocable.Action.createCustomAction(
                    'generateAiAgentResponse',
                    null,
                    AGENT_API_NAME,
                    AGENT_ACTION_VERSION
                )
                : Invocable.Action.createCustomAction(
                    'generateAiAgentResponse',
                    AGENT_API_NAME
                );

        action.setInvocationParameter(
            'userMessage',
            agentMessage
        );

        if (!String.isBlank(sessionId)) {
            action.setInvocationParameter(
                'sessionId',
                sessionId
            );
        }

        return action.invoke();
    }

    private static String buildAgentMessage(
        String command,
        String fieldContextJson
    ) {
        return
            'You are an intent router for an AI form chat. Understand the user sentence and return a structured command only. ' +
            'Use the provided current form fields to identify changed labels semantically. The user can ask for any label shown in the form, including labels that were renamed. ' +
            'Do not answer conversationally unless the user is asking for help. Do not update data yourself. The Salesforce controller will execute the command after your JSON response. ' +
            'Map the user sentence to exactly one action. ' +
            'Use action "fill" when the user asks to fill, complete, populate, autofill, enter from AI, or provide a value for one specific field and does not provide a replacement value. Return the matching fieldLabel, questionId, and empty newValue. ' +
            'Use action "replace" when the user provides a new value for one field. Equivalent words include replace, change, update, set, make, put, use, enter, input, insert, correct, should be, needs to be, has to be, and must be. Return the matching fieldLabel, questionId, and the exact newValue from the user. ' +
            'Use action "clear" when the user asks to clear, remove, delete, empty, erase, blank out, or no longer use one field. Return the matching fieldLabel, questionId, and empty newValue. ' +
            'Use action "clarify" only when the sentence does not include enough information to identify the action or the field. Ask a short clarificationQuestion. ' +
            'Use action "help" for greetings or general questions about what the form chat can do. ' +
            'For picklist or radio fields, newValue must be exactly one allowed option when replacing. If the user value is not an allowed option, return clarify. ' +
            'For date fields, newValue must be a valid date value from the user or source, not random text. If no valid date was provided, return fill or clarify, not replace. ' +
            'Return only JSON with keys: action, fieldLabel, questionId, newValue, needsClarification, clarificationQuestion. ' +
            'Examples: "can you fill Best Number to reach me" -> {"action":"fill","fieldLabel":"Best Number to reach me","questionId":"<matching id>","newValue":"","needsClarification":false,"clarificationQuestion":""}. ' +
            'Examples: "can you enter Best Number to reach me to 2345678901" -> {"action":"replace","fieldLabel":"Best Number to reach me","questionId":"<matching id>","newValue":"2345678901","needsClarification":false,"clarificationQuestion":""}. ' +
            'Examples: "remove GPA" -> {"action":"clear","fieldLabel":"GPA","questionId":"<matching id>","newValue":"","needsClarification":false,"clarificationQuestion":""}. ' +
            'Do not run the Fill Form Fields action and do not return fill_all. ' +
            'If the user asks to fill all fields, return {"action":"clarify","fieldLabel":"","questionId":"","newValue":"","needsClarification":true,"clarificationQuestion":"Fill all fields is handled by the form controller."}. ' +
            'Current form fields JSON: ' +
            (
                String.isBlank(fieldContextJson)
                    ? '[]'
                    : fieldContextJson
            ) +
            '. ' +
            'User command: ' +
            command;
    }

    private static Boolean isFillAllCommand(String command) {
        String normalized =
            command == null
                ? ''
                : command.toLowerCase();

        return
            normalized.contains('fill all') ||
            normalized.contains('autofill all') ||
            normalized.contains('auto fill all') ||
            normalized.contains('complete all') ||
            normalized.contains('populate all');
    }

    private static String getFirstTextOutput(Map<String, Object> outputParams) {
        if (outputParams == null) {
            return null;
        }

        List<String> keys =
            new List<String>{
                'structuredAgentResponse',
                'agentResponse',
                'answer',
                'resultJson'
            };

        for (String key : keys) {
            if (
                outputParams.containsKey(key) &&
                outputParams.get(key) != null
            ) {
                return String.valueOf(
                    outputParams.get(key)
                );
            }
        }

        return JSON.serialize(
            outputParams
        );
    }

    private static Map<String, Object> parseJsonObject(String value) {
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

        Object parsed =
            JSON.deserializeUntyped(
                jsonText
            );

        try {
            return (Map<String, Object>) parsed;
        }

        catch (Exception e) {
            return null;
        }
    }

    private static String valueAsString(Object value) {
        return value == null
            ? null
            : String.valueOf(value);
    }
}
