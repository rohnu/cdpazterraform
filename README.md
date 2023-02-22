
# Pre-requisites
      ssh Key: you will need to paste the public key into your parameters file
# CDP Installation:
•	CDP CLI (Instructions)
•	CDP Credential (Instructions)
o	You must set your Workload Password in your CDP Profile (Shortcut)
o	You must generate a CLI Access Key in your CDP Profile, and configure it to your local CDP CLI (Shortcut)

# To set up the CDP client, complete the following tasks: (Instructions)
•	Install the CDP client.
•	Generate an API access key.
•	Configure the CDP client with the API access key.

*Optional : Install the latest version of the Azure CLI. To start, run az login to create a connection with Azure.*

CLI Profile:

# By default, profile name should be default:

`cdp configure –-profile ${profileName}`

*Enter the following information at the prompt:*

1.	CDP Access key. Copy and paste the access key ID that you generated in the Management Console.
2.	CDP Private key. Copy and paste the private key that you generated in the Management Console.
The configuration utility creates the following file to store your user credentials: ~/.cdp/credentials

#CDP PARAMETER:

Create Environment parameter file like below *CDP_PARAMETER.JSON*

`{
    "environmentName": "ENVIRONMENT_NAME",
    "credentialName": "CREDENTIAL_NAME",
    "region": "REGION_TO_USE",
    "datalakeName": "DATALAKE_NAME",
    "scale": "LIGHT_DUTY",
    "runtime": "7.2.1",
    "groupName": "GROUP_NAME",
    "cdp_profile":    "default",
    "workload_pwd":   "PASSWORD",
    "publicKey": "SSH_KEYS",
    "proxyConfigName": "PROXY_CONFIG_NAME",
    "resourceGroupName": "RESOURCE_GROUP_NAME",
    "securityAccess": {
        "cidr": "",
        "securityGroupIdForKnox": "",
        "defaultSecurityGroupId": ""
    },
    "cloudProviderConfiguration": {
        "assumerManagedIdentity": "",
        "dataStorageLocation": "abfs://DATA_CONTAINER@STORAGE_NAME.dfs.core.windows.net",
        "dataManagedIdentity": "",
        "rangerManagedIdentity": ""
    },
    "logStorage": {
        "logStorageLocationBase": "abfs://LOG_CONTAINER@STORAGE_NAME.dfs.core.windows.net",
        "logManagedIdentity": ""
    },
    "existingNetworkParams": {
        "networkId": "NETWORK_NAME",
        "subnetIds": [
            "SUBNET_1","SUBNET_2","SUBNET_3"
        ]
    },
    "newNetworkParams": {
        "networkCidr": ""
    },
    "description": "DESCRIPTION",
    "freeIpa": {
        "instanceCountByGroup": 1
    },
    "mappings": [
        {
            "accessorCrn": "",
            "role": ""
        }
    ],
    "tags": [
        {
            "key": "",
            "value": ""
        }
    ],
    "datahub_list": [
            {
                "definition": "kafka.json",
                "custom_script": ""
            },
            {
                "definition": "flink.json",
                "custom_script": ""
            }
        ]
}`

#Set workload password:

`cdp --profile ${profileName}`

`cdp iam set-workload-password --password ${workload_pwd}`


# Environment Registration is three step process
    1) CDP ENVIRONMENT:

*If Network is created already then use below CDP command to register in CDP*

  `cdp environments create-azure-environment \
   --environment-name ${environmentName} \
   --credential-name ${credential} \
   --region "${region}" \
   --public-key "${publicKey}" \
   --log-storage storageLocationBase="${logStorageLocationBase}”,managedIdentity="${logManagedIdentity}" \
   --no-use-public-ip \
   --workload-analytics \
   --enable-tunnel  \
   --existing-network-params networkId="${networkID}”,resourceGroupName="${resourcegroup}",subnetIds="${subnetIds}" \
   --security-access
cidr="${cidr}”, securityGroupIdForKnox="${knox_id}”,defaultSecurityGroupId="${default_id}", \
   --free-ipa instanceCountByGroup=1 \
   --tags key=string,value=string`

*If Network is not created then use below CDP command to register in CDP*

  `cdp environments create-azure-environment
  --environment-name ${environmentName} \
  --credential-name ${credential} \
  --region "${region}" \
  --public-key "${publicKey}" \
  --log-storage storageLocationBase="${logStorageLocationBase}”,managedIdentity="${logManagedIdentity}" \
  --no-use-public-ip
  --workload-analytics \
  --enable-tunnel \
  --resource-group-name "${resourcegroup}" \
  --new-network-params networkCidr="{networkCidr}"
  --security-access cidr="${cidr}" \
  --free-ipa instanceCountByGroup=1 \
  --tags key=string,value=string`


#To check the status of the Environment creation: (Lookout for Available status)

`cdp environments describe-environment --environment-name ${environmentName}| jq -r .environment.status`



  2) CDP SET ID BROKER MAPPING:

  A CDP environment and Data Lake with no end user access to cloud storage. Adding users and groups to a CDP environment involves ensuring they are properly mapped to IAM roles to access cloud storage.

#Retrieve User CRN

`user_crn=$(cdp iam get-user | jq -r .user.crn)`

`group_crn=$(cdp iam list-groups --group-names $group_name | jq -r .groups[0].crn)`


  `cdp environments set-id-broker-mappings --environment-name ${environmentName} \
  --data-access-role ${dataManagedIdentity} --ranger-audit-role "${rangerManagedIdentity}" \
  --ranger-cloud-access-authorizer-role  "${rangerManagedIdentity}" --set-empty-mappings`

*Adding CDP user/group to IAM role mappings
Under the IDBroker Mappings, you can change the mappings of users or groups to IAM roles. The user or group dropdown is prepopulated with CDP users and groups. On the right-hand side, specify the role ARN (copied from the IAM role page) for that user or group that you are configuring.
For example, in the example setup we created the following roles:
DATAENG_ROLE - We created this role while onboarding users, and we assume that there is a DataEngineers group that was created in CDP.
DATASCI_ROLE - We created this role while onboarding users, and we assume that there is a DataScientists group that was created in CDP.*

  `cdp environments set-id-broker-mappings --environment-name ${environmentName} \
  --data-access-role ${dataManagedIdentity} --ranger-audit-role "${rangerManagedIdentity}" \
  --ranger-cloud-access-authorizer-role  "${rangerManagedIdentity}" --no-set-empty-mappings \
  --mappings accessorCrn=${user_crn or group_crn},role=${anyManagedIdentity}``


 3) CDP DATALAKE:

# CDP supported Data Lakes Scale or MEDIUM_DUTY

Use below command to create SDX or Datalake

`cdp datalake create-azure-datalake \
--datalake-name ${datalakeName} \
--environment-name ${environmentName} \
--cloud-provider-configuration
storageLocation="${dataStorageLocation}",managedIdentity="${assumerManagedIdentity}" \
--scale "${scale}" \
--runtime "${runtime}" \
--tags key=string,value=string`

To check the status of the Datalake creation: (Lookout for Available status)

`cdp environments describe-environment --environment-name ${environmentName} | jq -r .datalake.datalakeName`

# Sync ID Broker with datalake after datalake creation

`cdp environments sync-id-broker-mappings --environment-name ${environmentName}`

# Get Keytab:

`cdp environments get-keytab --environment-name ${environmentName} | jq -r '.contents' | base64 –decode`

# Synchronizes environments with user

A user to the FreeIPA servers.

`cdp environments sync-user`

output:

{
  "operationId": "c52f9e7d-0a1e-43db-ae33-e23297b3c3f6",
  "operationType": "USER_SYNC",
  "status": "RUNNING",
  "success": [],
  "failure": [],
  "startTime": "1602178446261"
}

# All users to the FreeIPA servers.

`cdp environments sync-all-users  --environment-name ${environmentName}`


To check the user sync status, use below command.

`cdp environments sync-status --operation-id c52f9e7d-0a1e-43db-ae33-e23297b3c3f6`

check status:

`cdp environments sync-status --operation-id c52f9e7d-0a1e-43db-ae33-e23297b3c3f6 | jq -r .status`


# DP DATAHUB:

`cdp datahub create-azure-cluster --cli-input-json “$(cat <kafka_template.json>)”`


# Get Subnet ID from the environment:


`cdp environments describe-environment --environment-name ${prefix}-cdp-env | jq -r .environment.network.subnetIds[0])`
