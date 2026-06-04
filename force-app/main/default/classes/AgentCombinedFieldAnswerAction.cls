public without sharing class AgentCombinedFieldAnswerAction {

    public class Request {
        @InvocableVariable(
            label='Question Id'
            description='Form question id for the combined answer field.'
        )
        public String questionId;

        @InvocableVariable(
            label='Question Label'
            description='Current form question label, such as What is your full address?'
            required=true
        )
        public String questionLabel;

        @InvocableVariable(
            label='Question Type'
            description='Form question type, such as Text or Textarea.'
        )
        public String questionType;
    }

    public class Response {
        @InvocableVariable(label='Question Id')
        public String questionId;

        @InvocableVariable(label='Value')
        public String value;

        @InvocableVariable(label='Source Fields')
        public String sourceFields;

        @InvocableVariable(label='Reasoning')
        public String reasoning;

        @InvocableVariable(label='Result JSON')
        public String resultJson;
    }

    @InvocableMethod(
        label='Build Combined Field Answer'
        description='Uses UserDataDiscoveryService to synthesize answers that combine multiple source fields.'
    )
    public static List<Response> buildCombinedAnswers(List<Request> requests) {
        List<Response> responses = new List<Response>();

        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        List<UserDataDiscoveryService.FormQuestion> questions =
            new List<UserDataDiscoveryService.FormQuestion>();

        for (Request request : requests) {
            UserDataDiscoveryService.FormQuestion question =
                new UserDataDiscoveryService.FormQuestion();
            question.questionId = String.isBlank(request.questionId)
                ? String.valueOf(questions.size() + 1)
                : request.questionId;
            question.questionText = request.questionLabel;
            question.questionType = request.questionType;
            questions.add(question);
        }

        Map<String, UserDataDiscoveryService.DataDiscoveryResult> results =
            UserDataDiscoveryService.discoverDataForForm(
                UserInfo.getUserId(),
                questions
            );

        for (UserDataDiscoveryService.FormQuestion question : questions) {
            UserDataDiscoveryService.DataDiscoveryResult result =
                results.get(question.questionId);

            Response response = new Response();
            response.questionId = question.questionId;

            if (result != null) {
                response.value = result.recommendedValue;
                response.reasoning = result.reasoning;
                response.sourceFields = result.sourceFields == null
                    ? null
                    : String.join(result.sourceFields, ', ');
            }

            response.resultJson = JSON.serialize(response);
            responses.add(response);
        }

        return responses;
    }
}
