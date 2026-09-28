@IsTest
private class AgentFindCaseTest {

    @TestSetup
    static void setup() {
        AgentTestDataFactory.createAccountsAndCases();
    }

    private static String caseNumberFor(String subject) {
        return [SELECT CaseNumber FROM Case WHERE Subject = :subject LIMIT 1].CaseNumber;
    }

    private static AgentFindCase.Request req(String caseNumber) {
        AgentFindCase.Request r = new AgentFindCase.Request();
        r.caseNumber = caseNumber;
        return r;
    }

    @IsTest
    static void findsExistingCaseWithFieldsNeededByPromptTemplate() {
        String num = caseNumberFor('Invoice amount incorrect');

        Test.startTest();
        AgentFindCase.Response res = AgentFindCase.find(new List<AgentFindCase.Request>{ req(num) })[0];
        Test.stopTest();

        Assert.isNotNull(res.caseRecord, 'Case should be found');
        Assert.areEqual('Found case ' + num + '.', res.message);
        // Summarize Case merges these fields; if they are not queried the template resolves blanks.
        Assert.areEqual('Invoice amount incorrect', res.caseRecord.Subject);
        Assert.areEqual('Working', res.caseRecord.Status);
        Assert.areEqual('Medium', res.caseRecord.Priority);
        Assert.isTrue(res.caseRecord.Description.contains('$182'));
    }

    @IsTest
    static void returnsNullRecordAndMessageWhenNotFound() {
        Test.startTest();
        AgentFindCase.Response res = AgentFindCase.find(new List<AgentFindCase.Request>{ req('99999999') })[0];
        Test.stopTest();

        Assert.isNull(res.caseRecord, 'No record means the agent must not call Summarize Case');
        Assert.areEqual('No case found with number 99999999.', res.message);
    }

    @IsTest
    static void trimsWhitespaceAroundCaseNumber() {
        String num = caseNumberFor('Login failure on portal');

        Test.startTest();
        AgentFindCase.Response res = AgentFindCase.find(new List<AgentFindCase.Request>{ req('  ' + num + ' ') })[0];
        Test.stopTest();

        Assert.isNotNull(res.caseRecord, 'LLM-extracted inputs can carry stray whitespace');
    }

    @IsTest
    static void handlesMixedBatchInOneQuery() {
        String num = caseNumberFor('Shipment delayed');
        List<AgentFindCase.Request> reqs = new List<AgentFindCase.Request>{ req(num), req('99999999') };

        Test.startTest();
        List<AgentFindCase.Response> results = AgentFindCase.find(reqs);
        Integer queriesUsed = Limits.getQueries();
        Test.stopTest();

        Assert.areEqual(2, results.size(), 'One response per request, in order');
        Assert.isNotNull(results[0].caseRecord);
        Assert.isNull(results[1].caseRecord);
        Assert.areEqual(1, queriesUsed, 'The action should run a single query regardless of batch size');
    }

    @IsTest
    static void enforcesRunningUserAccess() {
        String num = caseNumberFor('Invoice amount incorrect');
        User restricted = AgentTestDataFactory.createMinimumAccessUser();
        Boolean blocked = false;

        Test.startTest();
        System.runAs(restricted) {
            try {
                AgentFindCase.find(new List<AgentFindCase.Request>{ req(num) });
            } catch (QueryException e) {
                blocked = true;
            }
        }
        Test.stopTest();

        Assert.isTrue(blocked,
            'WITH USER_MODE must block a user without Case access rather than return data');
    }
}
