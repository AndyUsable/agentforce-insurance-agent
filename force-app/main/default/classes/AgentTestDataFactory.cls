/**
 * Shared test data for the Agentforce case actions.
 * Mirrors scripts/apex/seed-data.apex so tests and the demo org use the same scenarios.
 */
@IsTest
public class AgentTestDataFactory {

    public static void createAccountsAndCases() {
        List<Account> accts = new List<Account>{
            new Account(Name = 'Acme Corp'),
            new Account(Name = 'Globex Industries'),
            new Account(Name = 'Initech')
        };
        insert accts;

        insert new List<Case>{
            new Case(AccountId = accts[0].Id, Subject = 'Login failure on portal',
                     Status = 'New', Priority = 'High',
                     Description = 'Customer cannot log in to the policyholder portal.'),
            new Case(AccountId = accts[0].Id, Subject = 'Invoice amount incorrect',
                     Status = 'Working', Priority = 'Medium',
                     Description = 'Invoice shows $182 but the policy quote was $164.'),
            new Case(AccountId = accts[1].Id, Subject = 'Shipment delayed',
                     Status = 'New', Priority = 'Low'),
            new Case(AccountId = accts[2].Id, Subject = 'Password reset request',
                     Status = 'Closed', Priority = 'Low')
        };
    }

    /**
     * A user with no object permissions, used to prove WITH USER_MODE
     * blocks access instead of leaking data to the agent.
     */
    public static User createMinimumAccessUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
        String unique = String.valueOf(Datetime.now().getTime());
        User u = new User(
            Alias = 'minacc',
            Email = 'minaccess' + unique + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'MinimumAccess',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Chicago',
            Username = 'minaccess' + unique + '@agentforce-test.example.com'
        );
        insert u;
        return u;
    }
}
