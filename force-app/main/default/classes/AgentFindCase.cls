public with sharing class AgentFindCase {
    public class Request {
        @InvocableVariable(label='Case Number' description='The case number exactly as the user stated it, for example 00001027' required=true)
        public String caseNumber;
    }
    public class Response {
        @InvocableVariable(label='Case Record' description='The matching Case record, or null if not found')
        public Case caseRecord;
        @InvocableVariable(label='Message' description='Result message to show the user')
        public String message;
    }

    @InvocableMethod(label='Find Case by Number'
        description='Finds a support case by its case number. Use before summarizing or drafting a reply for a specific case.')
    public static List<Response> find(List<Request> requests) {
        Set<String> nums = new Set<String>();
        for (Request r : requests) nums.add(r.caseNumber.trim());

        Map<String, Case> byNum = new Map<String, Case>();
        for (Case c : [SELECT Id, CaseNumber, Subject, Status, Priority, Description
                       FROM Case WHERE CaseNumber IN :nums WITH USER_MODE]) {
            byNum.put(c.CaseNumber, c);
        }

        List<Response> out = new List<Response>();
        for (Request r : requests) {
            Response res = new Response();
            res.caseRecord = byNum.get(r.caseNumber.trim());
            res.message = res.caseRecord == null
                ? 'No case found with number ' + r.caseNumber + '.'
                : 'Found case ' + res.caseRecord.CaseNumber + '.';
            out.add(res);
        }
        return out;
    }
}