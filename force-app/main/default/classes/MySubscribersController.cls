/**
 * @description Controller for page MySubscribers which goal is to display
 *              information about packages in a dev hub and information where
 *              those packages are installed and by who.
 */
public class MySubscribersController {

    public class MySubscribersInformations {
        public MetadataPackageVersion version { public get; private set; }
        public MetadataPackage pack { public get; private set; }
        public Boolean isLastVersion { public get; private set; }
        public Boolean isBeta { public get; private set; }
        public List<PackageSubscriber> subscribers { public get; private set; }
        public List<Id> distinctProdOrgs { public get; private set; }
        public String updateScript { public get; private set; }
    }
    
    public List<MySubscribersInformations> information { public get; private set; }

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
        
        // Get unique list of package Ids, version Ids, subcribers, distinct none-sandbox org id by VersionId
        Set<Id> packageIds = new Set<Id>();
        Set<Id> versionIds = new Set<Id>();
        Map<Id, List<PackageSubscriber>> subscribersByVersion = new Map<Id, List<PackageSubscriber>>();
        Map<Id, Set<Id>> distinctProdOrgsByVersion = new Map<Id, Set<Id>>();
        for (PackageSubscriber sub : subscribers) {
            if (! subscribersByVersion.containsKey(sub.MetadataPackageVersionId)) {
                subscribersByVersion.put(sub.MetadataPackageVersionId, new List<PackageSubscriber>());
            }
            if (! distinctProdOrgsByVersion.containsKey(sub.MetadataPackageVersionId)) {
                distinctProdOrgsByVersion.put(sub.MetadataPackageVersionId, new Set<Id>());
            }
            subscribersByVersion.get(sub.MetadataPackageVersionId).add(sub);
            distinctProdOrgsByVersion.get(sub.MetadataPackageVersionId).add(sub.ParentOrg == null ? sub.OrgKey : sub.ParentOrg);
            packageIds.add(sub.MetadataPackageId);
            versionIds.add(sub.MetadataPackageVersionId);
        }

        // Selection of package version is rather long if you
        // don't specify filter. So we will only get information
        // about the package that were installed at least once 
        // by our subscribers.
        Map<Id, MetadataPackageVersion> packageVersions = new Map<Id, MetadataPackageVersion>([
            SELECT Id, Name, ReleaseState, IsDeprecated, 
                PatchVersion, BuildNumber, MinorVersion, MajorVersion,
                MetadataPackageId, SystemModstamp 
            FROM MetadataPackageVersion
            WHERE MetadataPackageId IN :packageIds
            ORDER BY MajorVersion DESC,  MinorVersion DESC, PatchVersion DESC, BuildNumber DESC
        ]);

        // For each version we want to have the latest version avaible (beta or released)
        Map<Id, MetadataPackageVersion> latestReleasedVersionByPackage = new Map<Id, MetadataPackageVersion>();
        for (MetadataPackageVersion v : packageVersions.values()) {
            // List 'packageVersions' is ordered by creation date descendent
            // So need only the first version of each packages
            if (! latestReleasedVersionByPackage.containsKey(v.MetadataPackageId) /*&& v.ReleaseState == 'Released'*/) {
                latestReleasedVersionByPackage.put(v.MetadataPackageId, v);
            }
        }
        
        // Get information for each package, because we cannot get
        // them direclty from the version SOQL! we will do it ourselves.
        Map<Id, MetadataPackage> packages = new Map<Id, MetadataPackage>([
            SELECT Id, Name, SystemModstamp 
            FROM MetadataPackage
            WHERE Id IN :packageIds
        ]);
        
        this.information = new List<MySubscribersInformations>();
        for (Id versionId : versionIds) {
            
            MetadataPackageVersion mtdVersion = packageVersions.get(versionId);
            Id packageId = mtdVersion.MetadataPackageId;
            MetadataPackage mtdPackage = packages.get(packageId);
            
            MySubscribersInformations i = new MySubscribersInformations();
            i.version = mtdVersion;
            i.pack = mtdPackage;
            i.isBeta = (mtdVersion.ReleaseState == 'Beta');
            i.subscribers = subscribersByVersion.get(versionId);
            i.distinctProdOrgs = new List<Id>(distinctProdOrgsByVersion.get(versionId));
            if (latestReleasedVersionByPackage.containsKey(packageId)) {
                i.isLastVersion = (latestReleasedVersionByPackage.get(packageId).Id == versionId);
                if (i.isLastVersion == false) {
                    i.updateScript =
                        'sfdx force:data:record:create --targetusername='+UserInfo.getUserName()+' --sobjecttype=PackagePushRequest "--values=PackageVersionId='+latestReleasedVersionByPackage.get(packageId).Id+'" --json > /tmp/out.txt <br />'+
                        'if [[ $(grep -c \'success": true\' /tmp/out.txt) -ne 1 ]]; then <br />'+
                        '&nbsp;&nbsp; echo \'PackagePushRequest record not created.\' <br />'+
                        'else <br />'+
                        '&nbsp;&nbsp; id=$(grep \'id": \' /tmp/out.txt | cut -d\'"\' -f4);  <br />'+
                        '&nbsp;&nbsp; csvFile=/tmp/packagePushJob-${id}.csv;  <br />'+
                        '&nbsp;&nbsp; echo "PackagePushRequestId,SubscriberOrganizationKey" > "${csvFile}"; <br />';
                    for (PackageSubscriber s : i.subscribers) {
	                    i.updateScript +=
                            '&nbsp;&nbsp; echo "${id},'+s.OrgKey+'" >> "${csvFile}"; <br />';
    	                    //'&nbsp;&nbsp; sfdx force:data:record:create --targetusername='+UserInfo.getUserName()+' --sobjecttype=PackagePushJob "--values=PackagePushRequestId=${id} SubscriberOrganizationKey='+s.OrgKey+'"<br />';
                    }
                    i.updateScript +=
                        '&nbsp;&nbsp; sfdx force:data:bulk:upsert --targetusername='+UserInfo.getUserName()+' -s PackagePushJob -f "${csvFile}" -i Id <br />'+
                        '&nbsp;&nbsp; sfdx force:data:record:update --targetusername='+UserInfo.getUserName()+' --sobjecttype=PackagePushRequest --sobjectid=${id} "--values=Status=Pending" <br />'+
                        'fi <br />';
            	}
            } else {
                i.isLastVersion = false;
            }
            this.information.add(i);
        }
    }
}