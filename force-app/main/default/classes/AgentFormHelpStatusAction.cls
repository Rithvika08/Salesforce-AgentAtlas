public without sharing class AgentFormHelpStatusAction {

    public class Request {
        @InvocableVariable(
            label='User Question'
            description='General user question about the AI form filler.'
        )
        public String question;
    }

    public class Response {
        @InvocableVariable(label='Answer')
        public String answer;

        @InvocableVariable(label='Result JSON')
        public String resultJson;
    }

    @InvocableMethod(
        label='Get AI Form Help'
        description='Returns general guidance about what the AI form filler can do.'
    )
    public static List<Response> getFormHelp(List<Request> requests) {
        List<Response> responses = new List<Response>();

        if (requests == null || requests.isEmpty()) {
            requests = new List<Request>{ new Request() };
        }

        for (Request request : requests) {
            Response response = new Response();
            response.answer =
                'I can help fill all fields, fill a specific field, replace a field value, clear a field, and understand changed question labels using the AI extraction layer.';
            response.resultJson = JSON.serialize(response);
            responses.add(response);
        }

        return responses;
    }
}
