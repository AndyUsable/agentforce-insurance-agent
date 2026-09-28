/**
 * Agent action: returns open cases for one or more customer accounts.
 *
 * Bulk-safe: one SOQL query for the whole batch. A parent-child subquery gives
 * every matching account its own 10-case cap, so one very busy account cannot
 * crowd out the others in the same batch.
 *
 * Runs WITH USER_MODE so the agent only sees what the running user can see.
 */
public with sharing class AgentCaseLookup {

    private static final Integer MAX_CASES_PER_REQUEST = 10;

    public class Request {
        @InvocableVariable(label='Account Name' description='The name of the customer account to look up cases for' required=true)
        public String accountName;
    }

    public class Response {
        @InvocableVariable(label='Case Summary' description='A list of open cases with number, subject, status, and priority')
        public String summary;
    }

    @InvocableMethod(label='Get Open Cases for Account'
        description='Returns open cases for a customer account by account name. Use when the user asks about a customer\'s open cases, issues, or support status.')
    public static List<Response> getOpenCases(List<Request> requests) {
        List<String> patterns = new List<String>();
        for (Request req : requests) {
            if (String.isNotBlank(req.accountName)) {
                patterns.add('%' + req.accountName.trim() + '%');
            }
        }

        // Only accounts that actually have open cases (semi-join), each with its own case cap.
        // Known limit: a batch whose names match more than 1,000 such accounts is truncated.
        // Agents call this action one account at a time, so this does not occur in practice.
        List<Account> accounts = patterns.isEmpty() ? new List<Account>() : [
            SELECT Name,
                (SELECT CaseNumber, Subject, Status, Priority
                 FROM Cases
                 WHERE IsClosed = false
                 ORDER BY CaseNumber
                 LIMIT 10)
            FROM Account
            WHERE Name LIKE :patterns
              AND Id IN (SELECT AccountId FROM Case WHERE IsClosed = false)
            WITH USER_MODE
            ORDER BY Name
            LIMIT 1000
        ];

        List<Response> results = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();
            if (String.isBlank(req.accountName)) {
                res.summary = 'No account name was provided.';
                results.add(res);
                continue;
            }

            String needle = req.accountName.trim().toLowerCase();
            List<String> lines = new List<String>();
            for (Account acct : accounts) {
                if (!acct.Name.toLowerCase().contains(needle)) {
                    continue;
                }
                for (Case c : acct.Cases) {
                    if (lines.size() == MAX_CASES_PER_REQUEST) {
                        break;
                    }
                    lines.add(c.CaseNumber + ' | ' + c.Subject + ' | ' + c.Status + ' | ' + c.Priority);
                }
                if (lines.size() == MAX_CASES_PER_REQUEST) {
                    break;
                }
            }

            res.summary = lines.isEmpty()
                ? 'No open cases found for "' + req.accountName + '".'
                : String.join(lines, '\n');
            results.add(res);
        }
        return results;
    }
}