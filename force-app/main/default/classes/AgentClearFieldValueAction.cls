public without sharing class AgentClearFieldValueAction {

    public class Request {
        @InvocableVariable(
            label='User Command'
            description='Natural language command, such as clear GPA or remove faculty advisor name.'
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
    }

    public class Response {
        @InvocableVariable(label='Action')
        public String action;

        @InvocableVariable(label='Target Question Id')
        public String questionId;

        @InvocableVariable(label='Target Field Label')
        public String fieldLabel;

        @InvocableVariable(label='Needs Clarification')
        public Boolean needsClarification;

        @InvocableVariable(label='Clarification Question')
        public String clarificationQuestion;

        @InvocableVariable(label='Result JSON')
        public String resultJson;
    }

    @InvocableMethod(
        label='Apply Field Clear'
        description='Understands and prepares a safe clear/remove command for the AI form filler.'
    )
    public static List<Response> clearFieldValues(List<Request> requests) {
        List<Response> responses = new List<Response>();

        if (requests == null || requests.isEmpty()) {
            requests = new List<Request>{ new Request() };
        }

        for (Request request : requests) {
            Response response = buildClearResponse(request);
            response.resultJson = JSON.serialize(response);
            responses.add(response);
        }

        return responses;
    }

    private static Response buildClearResponse(Request request) {
        Response response = new Response();
        response.action = 'clear';
        response.questionId = request == null ? null : request.questionId;
        response.fieldLabel = request == null ? null : request.fieldLabel;
        response.needsClarification = false;

        String command = request == null ? null : request.command;

        if (String.isBlank(command)) {
            response.needsClarification = true;
            response.clarificationQuestion = 'Which field should I clear?';
            return response;
        }

        if (
            String.isBlank(response.questionId) &&
            String.isBlank(response.fieldLabel)
        ) {
            response.fieldLabel = extractSimpleFieldLabel(command);
        }

        if (
            String.isBlank(response.questionId) &&
            String.isBlank(response.fieldLabel)
        ) {
            response.needsClarification = true;
            response.clarificationQuestion = 'Which field should I clear?';
        }

        return response;
    }

    private static String extractSimpleFieldLabel(String command) {
        if (String.isBlank(command)) {
            return null;
        }

        String normalized = command.trim();
        String lower = normalized.toLowerCase();

        List<String> prefixes = new List<String>{
            'clear ',
            'remove ',
            'delete ',
            'empty '
        };

        for (String prefix : prefixes) {
            if (lower.startsWith(prefix)) {
                return normalized.substring(prefix.length()).trim();
            }
        }

        return null;
    }
}
