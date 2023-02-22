#!/bin/bash
set -o nounset

display_usage() {
    echo "
Usage:
    $(basename "$0") [--help or -h] <cdp_parameter> (<network_created>)
Description:
    Launches a CDP Azure environment
Arguments:
    cdp__parameter:                CDP Environment Parameter file in json
    network_created:               (optional) flag to see if network was created (possible values: yes or no)
    --help or -h:   displays this help"

}

if [[ ( ${1:-x} == "--help") ||  ${1:-x} == "-h" ]]
then
    display_usage
    exit 0
fi


# Check the numbers of arguments
if [  $# -lt 2 ]
then
    echo "Not enough arguments!" >&2
    display_usage
    exit 1
fi

if [  $# -gt 2 ]
then
    echo "Too many arguments!" >&2
    display_usage
    exit 1
fi

#Retrieve User CRN
user_crn=$(cdp iam get-user | jq -r .user.crn)


envName=$(cat $1 | jq -r .environmentName)
credential=$(cat $1 | jq -r .credentialName)
region=$(cat $1 | jq -r .region)
resourcegroup=$(cat $1 | jq -r .resourceGroupName)
publicKey=$(cat $1 | jq -r .publicKey)
logURL=$(cat $1 | jq -r .logStorage.storageLocationBase)
logMSI=$(cat $1 | jq -r .logStorage.logManagedID)

if [  $# -gt 1 ]
then
    network_created=$2
    networkID=$(cat $1 | jq -r .existingNetworkParams.networkId)
    subnetIds=$(cat $1 | jq -c .existingNetworkParams.subnetIds |  sed 's/[][]//g')
    cidr=$(cat $1 | jq -r .securityAccess.cidr)
    #knox_nsg=$(az network nsg show -g $resourcegroup -n $networkID-knox-nsg | jq -r .id)
    #default_nsg=$(az network nsg show -g $resourcegroup -n $networkID-default-nsg | jq -r .id)
fi

#DATA_MSI_ID=$(az identity list -g $resourcegroup --query "[?name=='$resourcegroup-DataAccessIdentity']" | jq -r '.[0].id' | sed -e "s|resourcegroup|resourceGroup|g" )
#RANGER_MSI_ID=$(az identity list -g $resourcegroup --query "[?name=='$resourcegroup-RANGERAccessIdentity']" | jq -r '.[0].id' | sed -e "s|resourcegroup|resourceGroup|g" )
#ASSUMER_MSI_ID=$(az identity list -g $resourcegroup --query "[?name=='$resourcegroup-AssumerIdentity']" | jq -r '.[0].id' | sed -e "s|resourcegroup|resourceGroup|g" )
LOGGER_MSI_ID=$(az identity list -g $resourcegroup --query "[?name=='${logMSI}']" | jq -r '.[0].id' | sed -e "s|resourcegroup|resourceGroup|g" )


TAGS=$(cat $1| jq -r .tags)
flattened_tags=""
for item in $(echo "${TAGS}" | jq -r '.[] | @base64'); do
  _jq() {
    echo ${item} | base64 --decode | jq -r ${1}
  }
  key=$(_jq '.key')
  value=$(_jq '.value')
  flattened_tags=$flattened_tags" key=\"$key\",value=\"$value\""
done
echo $flattened_tags

if [[ "$network_created" == "yes" ]]
then
  cdp environments create-azure-environment --environment-name ${envName} \
  --credential-name ${credential} --region "${region}" \
  --public-key "${publicKey}" \
  --log-storage storageLocationBase="${logURL}",managedIdentity="${LOGGER_MSI_ID}" \
  --use-public-ip --workload-analytics \
  --existing-network-params networkId="${networkID}",resourceGroupName="${resourcegroup}",subnetIds="${subnetIds}" \
  --security-access cidr="${cidr}" \
  --enable-tunnel  \
  --free-ipa instanceCountByGroup=1  \
  --tags ${flattened_tags}
else
  cdp environments create-azure-environment --environment-name ${envName} \
  --credential-name ${credential} --region "${region}" \
  --public-key "${publicKey}" \
  --log-storage storageLocationBase="${logURL}",managedIdentity="${LOGGER_MSI_ID}" \
  --use-public-ip --workload-analytics \
  --resource-group-name "${resourcegroup}" \
  --new-network-params networkCidr="10.10.0.0/16"
  --security-access cidr="${cidr}" \
  --enable-tunnel  \
  --free-ipa instanceCountByGroup=1  \
  --tags ${flattened_tags}
fi
sleep 60
status=$(cdp environments describe-environment --environment-name ${envName} | jq -r .environment.status)
while [ $status == "FREEIPA_CREATION_IN_PROGRESS" ]
do
  # Communicate that we're waiting.
  echo " Status: $status"
  sleep 30
  # Re run the command.
  status=$(cdp environments describe-environment --environment-name ${envName} | jq -r .environment.status)
done

# Environment Creation has finished.
echo "CDP Environment is ${status}"
