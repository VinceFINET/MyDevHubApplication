/**
 * @description Controller for page MySubscribers which goal is to display
 *              information about packages in a dev hub and information where
 *              those packages are installed and by who.
 */
public class MySubscribersController {

    /** 
	 * @description Inner class to gather package / version information at once 
	 */
    public class PackageInformation {
        public MetadataPackageVersion version { public get; private set; }
        public MetadataPackage pack { public get; private set; }
        public Integer numberSubscriptions { public get; private set; }
    }
    
    /** 
	 * @description Inner class to gather subscription information (the subscriber 
	 *              and the package version installed) 
	 */
    public class SubscriptionInformation {
        public PackageSubscriber subscriber { public get; private set; }
        public PackageInformation packageInformation { public get; private set; }
    }
    
    /**
     * @description Subscriptions list for Visual Force Page
     */
    public List<SubscriptionInformation> subscriptions { public get; private set; }

    /**
     * @description Package/Version list for Visual Force Page
     */
    public List<PackageInformation> packageInformations { public get; private set; }
    
    /** 
     * @description Constructor of the controller will set the two lists
     */
    public MySubscribersController() {
        
        // List of subscribers from this devhub and the 
        //    package version they are using
        List<PackageSubscriber> subscribers = [
            SELECT InstanceName, MetadataPackageId, 
                MetadataPackageVersionId, OrgKey, OrgName, 
            	OrgStatus, OrgType, ParentOrg, SystemModstamp
            FROM PackageSubscriber
            WHERE InstalledStatus = 'i' 
            ORDER BY SystemModstamp DESC
        ];
        
        // Get unique list of package and version Ids
        Set<Id> packageIds = new Set<Id>();
        Set<Id> packageVersionIds = new Set<Id>();
        for (PackageSubscriber sub : subscribers) {
            packageIds.add(sub.MetadataPackageId);
            packageVersionIds.add(sub.MetadataPackageVersionId);
        }
        
        // Selection of package version is rather long if you
        // don't specify filter. So we will only get information
        // about the package that were installed at least once 
        // by our subscribers.
        List<MetadataPackageVersion> packageVersions = [
            SELECT Id, Name, ReleaseState, IsDeprecated, 
                PatchVersion, BuildNumber, MinorVersion, MajorVersion,
                MetadataPackageId, SystemModstamp 
            FROM MetadataPackageVersion
            WHERE MetadataPackageId IN :packageIds
            ORDER BY SystemModstamp DESC
        ];
        
        // Get information for each package, because we cannot get
        // them direclty from the version SOQL! we will do it ourselves.
        Map<Id, MetadataPackage> packages = new Map<Id, MetadataPackage>([
            SELECT Id, Name, SystemModstamp 
            FROM MetadataPackage
            WHERE Id IN :packageIds
        ]);
        
        // Construct a map of package informations with the 
        // package version id as key
        Map<Id, PackageInformation> packageInformations = new Map<Id, PackageInformation>();
        for (MetadataPackageVersion v : packageVersions) {
            PackageInformation pi = new PackageInformation();
            pi.version = v;
            pi.pack = packages.get(v.MetadataPackageId);
            pi.numberSubscriptions = 0;
            packageInformations.put(v.Id, pi);
        }
        
        // Finally start constructing the subscriptions list
        // With subcribers info and version information
        // Along with the list of version that are installed by 
        // subscribers only (filter in Apex because too long in SOQL!)
        this.subscriptions = new List<SubscriptionInformation>();
        this.packageInformations = new List<PackageInformation>();
        for (PackageSubscriber sub : subscribers) {
            SubscriptionInformation si = new SubscriptionInformation();
            si.subscriber = sub;
            si.packageInformation = packageInformations.get(sub.MetadataPackageVersionId);
            si.packageInformation.numberSubscriptions++;
            if (si.packageInformation.numberSubscriptions == 1) {
                this.packageInformations.add(si.packageInformation);
            }
            this.subscriptions.add(si);
        }
    }
}