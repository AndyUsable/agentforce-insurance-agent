// Seed data for the Agentforce Insurance Agent demo.
// Run with: sf apex run --file scripts/apex/seed-data.apex --target-org <alias>
List<Account> accts = new List<Account>{
    new Account(Name = 'Acme Corp'),
    new Account(Name = 'Globex Industries'),
    new Account(Name = 'Initech')
};
insert accts;

insert new List<Case>{
    new Case(AccountId = accts[0].Id, Subject = 'Login failure on portal', Status = 'New', Priority = 'High',
        Description = 'Customer reports they cannot log in to the policyholder portal since Monday. Password reset email never arrives. They need to download their auto ID card before a traffic stop deadline on Friday.'),
    new Case(AccountId = accts[0].Id, Subject = 'Invoice amount incorrect', Status = 'Working', Priority = 'Medium',
        Description = 'Customer says their monthly premium invoice shows $182 but their policy quote was $164. They were told the Saver plan discount would apply. Customer is frustrated and mentions switching carriers.'),
    new Case(AccountId = accts[1].Id, Subject = 'Shipment delayed', Status = 'New', Priority = 'Low',
        Description = 'Customer ordered replacement policy documents by mail two weeks ago and has not received them. Address on file was confirmed correct.'),
    new Case(AccountId = accts[2].Id, Subject = 'Password reset request', Status = 'Closed', Priority = 'Low')
};