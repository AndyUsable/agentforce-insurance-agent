@IsTest
private class AgentCaseLookupTest {

    @TestSetup
    static void setup() {
        AgentTestDataFactory.createAccountsAndCases();
    }

    private static AgentCaseLookup.Response lookup(String accountName) {
        AgentCaseLookup.Request req = new AgentCaseLookup.Request();
        req.accountName = accountName;
        return AgentCaseLookup.getOpenCases(new List<AgentCaseLookup.Request>{ req })[0];
    }

    @IsTest
    static void returnsOnlyOpenCasesForMatchingAccount() {
        Test.startTest();
        AgentCaseLookup.Response res = lookup('Acme');
        Test.stopTest();

        List<String> lines = res.summary.split('\n');
        Assert.areEqual(2, lines.size(), 'Acme has exactly two open cases');
        Assert.isTrue(res.summary.contains('Login failure on portal | New | High'),
            'Each line should include subject, status and priority');
        Assert.isTrue(res.summary.contains('Invoice amount incorrect | Working | Medium'),
            'Working cases count as open');
    }

    @IsTest
    static void excludesClosedCases() {
        Test.startTest();
        AgentCaseLookup.Response res = lookup('Initech');
        Test.stopTest();

        Assert.areEqual('No open cases found for "Initech".', res.summary,
            'Closed cases must not be reported as open');
    }

    @IsTest
    static void returnsExplicitMessageForUnknownAccount() {
        Test.startTest();
        AgentCaseLookup.Response res = lookup('Wayne Enterprises');
        Test.stopTest();

        // An explicit message stops the agent from inventing an answer.
        Assert.areEqual('No open cases found for "Wayne Enterprises".', res.summary);
    }

    @IsTest
    static void matchesPartialCaseInsensitiveNames() {
        Test.startTest();
        AgentCaseLookup.Response res = lookup('glob');
        Test.stopTest();

        Assert.isTrue(res.summary.contains('Shipment delayed'),
            'Users type partial, lowercase names; the lookup should still match');
    }

    @IsTest
    static void handlesMultipleRequestsInOrder() {
        List<AgentCaseLookup.Request> reqs = new List<AgentCaseLookup.Request>();
        for (String name : new List<String>{ 'Acme', 'Initech', 'Globex' }) {
            AgentCaseLookup.Request r = new AgentCaseLookup.Request();
            r.accountName = name;
            reqs.add(r);
        }

        Test.startTest();
        List<AgentCaseLookup.Response> results = AgentCaseLookup.getOpenCases(reqs);
        Test.stopTest();

        Assert.areEqual(3, results.size(), 'One response per request');
        Assert.isTrue(results[0].summary.contains('Login failure on portal'));
        Assert.isTrue(results[1].summary.startsWith('No open cases'));
        Assert.isTrue(results[2].summary.contains('Shipment delayed'));
    }

    @IsTest
    static void enforcesRunningUserAccess() {
        User restricted = AgentTestDataFactory.createMinimumAccessUser();
        Boolean blocked = false;

        Test.startTest();
        System.runAs(restricted) {
            try {
                lookup('Acme');
            } catch (QueryException e) {
                blocked = true;
            }
        }
        Test.stopTest();

        Assert.isTrue(blocked,
            'WITH USER_MODE must block a user without Case access rather than return data');
    }
    
    @IsTest
    static void usesOneQueryForAnyBatchSize() {
        List<AgentCaseLookup.Request> reqs = new List<AgentCaseLookup.Request>();
        for (String name : new List<String>{ 'Acme', 'Initech', 'Globex', 'Wayne Enterprises' }) {
            AgentCaseLookup.Request r = new AgentCaseLookup.Request();
            r.accountName = name;
            reqs.add(r);
        }

        Test.startTest();
        AgentCaseLookup.getOpenCases(reqs);
        Integer queriesUsed = Limits.getQueries();
        Test.stopTest();

        Assert.areEqual(1, queriesUsed, 'The action should run a single query regardless of batch size');
    }

    @IsTest
    static void handlesBlankAccountName() {
        Test.startTest();
        AgentCaseLookup.Response res = lookup('  ');
        Test.stopTest();

        Assert.areEqual('No account name was provided.', res.summary);
    }

    @IsTest
    static void busyAccountDoesNotCrowdOutOthersInBatch() {
        Account busy = new Account(Name = 'Umbrella Corp');
        insert busy;
        List<Case> many = new List<Case>();
        for (Integer i = 0; i < 12; i++) {
            many.add(new Case(AccountId = busy.Id, Subject = 'Umbrella issue ' + i,
                              Status = 'New', Priority = 'Low'));
        }
        insert many;

        AgentCaseLookup.Request busyReq = new AgentCaseLookup.Request();
        busyReq.accountName = 'Umbrella';
        AgentCaseLookup.Request otherReq = new AgentCaseLookup.Request();
        otherReq.accountName = 'Globex';

        Test.startTest();
        List<AgentCaseLookup.Response> results =
            AgentCaseLookup.getOpenCases(new List<AgentCaseLookup.Request>{ busyReq, otherReq });
        Test.stopTest();

        Assert.areEqual(10, results[0].summary.split('\n').size(),
            'A busy account is capped at 10 cases');
        Assert.isTrue(results[1].summary.contains('Shipment delayed'),
            'Other accounts in the same batch must still get their own results');
    }
}