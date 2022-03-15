public with sharing class MyCustomersController {

    public class Company {
        public String Name { public get; private set; }
        public String MainOrgKey { public get; private set; }
        public Integer numProdOrgs { public get; private set; }
        public Integer numSandboxOrgs { public get; private set; }
        public Integer numTrialOrgs { public get; private set; }
        public Integer numDevEdOrgs { public get; private set; }
        public Integer numOtherOrgs { public get; private set; }
        public List<Organization> Organizations { public get; private set; }
    }
    
    public enum Category {
        SANDBOX,
        PRODUCTION,
        TRIAL,
        DEMO,
        OTHER
    }
    public Category Category_SANDBOX    { get { return Category.SANDBOX; } }
    public Category Category_PRODUCTION { get { return Category.PRODUCTION; } }
    public Category Category_TRIAL      { get { return Category.TRIAL; } }
    public Category Category_DEMO       { get { return Category.DEMO; } }
    public Category Category_OTHER      { get { return Category.OTHER; } }
    
    public class Organization {
        public String InstanceName { public get; private set; }
        public String OrgKey { public get; private set; }
        public String OrgName { public get; private set; }
        public String OrgStatus { public get; private set; }
        public String OrgType { public get; private set; }
        public Category OrgCategory { public get; private set; }
    }
    
    public Map<String, Company> companies { public get; private set; }
    
    public MyCustomersController() {

        List<PackageSubscriber> subscribers = [
            SELECT InstanceName, MetadataPackageId, 
                MetadataPackageVersionId, OrgKey, OrgName, 
            	OrgStatus, OrgType, ParentOrg, SystemModstamp
            FROM PackageSubscriber
            WHERE InstalledStatus = 'i' 
            ORDER BY SystemModstamp DESC
        ];
        
        this.companies = new Map<String, Company>();
        
        for (PackageSubscriber ps : subscribers) {
            String mainOrgId = ps.ParentOrg != null ? ps.ParentOrg : ps.OrgKey;
            String key = ps.OrgName + mainOrgId;
            if (this.companies.containsKey(key) == false) {
                Company company = new Company();
                company.Name = ps.OrgName;
                company.MainOrgKey = mainOrgId;
                company.numProdOrgs = 0;
                company.numSandboxOrgs = 0;
                company.numTrialOrgs = 0;
                company.numDevEdOrgs = 0;
                company.numOtherOrgs = 0;
                company.Organizations = new List<Organization>();
                this.companies.put(key, company);
            }
            Company company = this.companies.get(key);
            Organization org = new Organization();
            org.InstanceName = ps.InstanceName;
            org.OrgKey = ps.OrgKey;
            org.OrgName = ps.OrgName;
            org.OrgStatus = ps.OrgStatus;
            org.OrgType = ps.OrgType;
            switch on (ps.OrgStatus + ps.OrgType) {
                when 'DemoSandbox'      { org.OrgCategory = Category.SANDBOX; }
                when 'ActiveProduction' { org.OrgCategory = Category.PRODUCTION; }
                when 'TrialProduction'  { org.OrgCategory = Category.TRIAL; }
                when 'FreeProduction'   { org.OrgCategory = Category.DEMO; }
                when else               { org.OrgCategory = Category.OTHER; }
            }
            company.Organizations.add(org);
            
            switch on org.OrgCategory {
                when SANDBOX    { company.numSandboxOrgs++; }
                when PRODUCTION { company.numProdOrgs++; }
                when TRIAL      { company.numTrialOrgs++;  }
                when DEMO       { company.numDevEdOrgs++; }
                when OTHER      { company.numOtherOrgs++; }
            }
        }
    }
}
