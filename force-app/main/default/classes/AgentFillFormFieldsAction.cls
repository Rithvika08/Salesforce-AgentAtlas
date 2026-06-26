public without sharing class AgentFillFormFieldsAction {

    public class Request {
        @InvocableVariable(
            label='Command'
            description='Optional user command, such as fill all fields or fill missing fields.'
        )
        public String command;
    }

    public class Response {
        @InvocableVariable(
            label='Result JSON'
            description='JSON response from the existing AI form fill controller.'
        )
        public String resultJson;
    }

    @InvocableMethod(
        label='Fill Form Fields'
        description='Runs the existing AI form autofill flow and returns the filled field results as JSON.'
    )
    public static List<Response> fillFields(List<Request> requests) {
        List<Response> responses = new List<Response>();

        Integer requestCount = requests == null || requests.isEmpty()
            ? 1
            : requests.size();

        for (Integer i = 0; i < requestCount; i++) {
            Response response = new Response();
            response.resultJson = JSON.serialize(
                AIFormFillerController.fillFormWithAI(null)
            );
            responses.add(response);
        }

        return responses;
    }
}
