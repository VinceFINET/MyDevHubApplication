public with sharing class MyCustomersController {

    public class Company {
        public String Name { public get; private set; }
        public String MainOrgKey { public get; private set; }
        public List<Organization> Organizations { public get; private set; }
    }
    public class Organization {
        public String InstanceName { public get; private set; }
        public String OrgKey { public get; private set; }
        public String OrgName { public get; private set; }
        public String OrgStatus { public get; private set; }
        public String OrgType { public get; private set; }
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
            company.Organizations.add(org);
        }
    }
}