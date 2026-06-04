public without sharing class AgentReplaceFieldValueAction {

    public class Request {
        @InvocableVariable(
            label='User Command'
            description='Natural language command, such as change GPA to 3.8 or set preferred contact method to Phone.'
            required=true
        )
        public String command;

        @InvocableVariable(
            label='Target Question Id'
            description='Optional form question id when the target field is already known.'
        )
        public String questionId;

        @InvocableVariable(
            label='Target Field Label'
            description='Optional form field label when the target field is already known.'
        )
        public String fieldLabel;

        @InvocableVariable(
            label='New Value'
            description='Optional replacement value when it has already been extracted.'
        )
        public String newValue;
    }

    public class Response {
        @InvocableVariable(
            label='Action'
            description='The action the form should perform.'
        )
        public String action;

        @InvocableVariable(
            label='Target Question Id'
            description='The question id to update, when identified.'
        )
        public String questionId;

        @InvocableVariable(
            label='Target Field Label'
            description='The field label to update, when identified.'
        )
        public String fieldLabel;

        @InvocableVariable(
            label='New Value'
            description='The replacement value to apply.'
        )
        public String newValue;

        @InvocableVariable(
            label='Needs Clarification'
            description='True when the command does not include enough information to safely update a field.'
        )
        public Boolean needsClarification;

        @InvocableVariable(
            label='Clarification Question'
            description='Question the agent should ask before updating the form.'
        )
        public String clarificationQuestion;

        @InvocableVariable(
            label='Result JSON'
            description='Structured JSON result for the form UI or agent.'
        )
        public String resultJson;
    }

    @InvocableMethod(
        label='Apply Field Replacement'
        description='Understands and prepares a safe field replacement command for the AI form filler.'
    )
    public static List<Response> replaceFieldValues(List<Request> requests) {
        List<Response> responses = new List<Response>();

        if (requests == null || requests.isEmpty()) {
            requests = new List<Request>{ new Request() };
        }

        for (Request request : requests) {
            Response response = buildReplacementResponse(request);
            response.resultJson = JSON.serialize(response);
            responses.add(response);
        }

        return responses;
    }

    private static Response buildReplacementResponse(Request request) {
        Response response = new Response();
        response.action = 'replace';
        response.questionId = request == null ? null : request.questionId;
        response.fieldLabel = request == null ? null : request.fieldLabel;
        response.newValue = request == null ? null : request.newValue;
        response.needsClarification = false;

        String command = request == null ? null : request.command;

        if (String.isBlank(command)) {
            response.needsClarification = true;
            response.clarificationQuestion =
                'Which field should I update, and what value should I use?';
            return response;
        }

        if (String.isBlank(response.newValue)) {
            response.newValue = extractSimpleReplacementValue(command);
        }

        if (
            String.isBlank(response.questionId) &&
            String.isBlank(response.fieldLabel)
        ) {
            response.fieldLabel = extractSimpleFieldLabel(command);
        }

        if (String.isBlank(response.newValue)) {
            response.needsClarification = true;
            response.clarificationQuestion =
                'What value should I use for ' +
                (
                    String.isBlank(response.fieldLabel)
                        ? 'that field'
                        : response.fieldLabel
                ) +
                '?';
        }

        if (
            String.isBlank(response.questionId) &&
            String.isBlank(response.fieldLabel)
        ) {
            response.needsClarification = true;
            response.clarificationQuestion =
                'Which field should I update?';
        }

        return response;
    }

    private static String extractSimpleReplacementValue(String command) {
        if (String.isBlank(command)) {
            return null;
        }

        String lower = command.toLowerCase();
        List<String> separators = new List<String>{
            ' to ',
            ' as ',
            ' with ',
            ' be '
        };

        for (String separator : separators) {
            Integer index = lower.lastIndexOf(separator);
            if (index >= 0 && index + separator.length() < command.length()) {
                return command.substring(index + separator.length()).trim();
            }
        }

        return null;
    }

    private static String extractSimpleFieldLabel(String command) {
        if (String.isBlank(command)) {
            return null;
        }

        String normalized = command.trim();
        String lower = normalized.toLowerCase();

        List<String> prefixes = new List<String>{
            'change ',
            'replace ',
            'update ',
            'set '
        };

        for (String prefix : prefixes) {
            if (lower.startsWith(prefix)) {
                normalized = normalized.substring(prefix.length()).trim();
                lower = normalized.toLowerCase();
                break;
            }
        }

        List<String> separators = new List<String>{
            ' to ',
            ' as ',
            ' with ',
            ' be '
        };

        for (String separator : separators) {
            Integer index = lower.indexOf(separator);
            if (index > 0) {
                return normalized.substring(0, index).trim();
            }
        }

        return null;
    }
}
