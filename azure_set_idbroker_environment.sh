#!/bin/bash
set -o nounset

display_usage() {
    echo "
Usage:
    $(basename "$0") [--help or -h] <cdp_parameter> (<mapping>)
Description:
    Launches a CDP Azure environment
Arguments:
    cdp_parameter:                CDP ID Broker Parameter file in json
    mapping:                      (optional) flag to see if mapping was selected (possible values: yes or no)
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

envName=$(cat $1 | jq -r .environmentName)
resourcegroup=$(cat $1 | jq -r .resourceGroupName)
dataMSI=$(cat $1 | jq -r .cloudProviderConfiguration.dataManagedID)
rangerMSI=$(cat $1 | jq -r .cloudProviderConfiguration.rangerManagedID)
ASSUMER_MSI_ID=$(cat $1 | jq -r .cloudProviderConfiguration.managedIdentity)

if [  $# -gt 1 ]
then
    mapping=$2
    #group_name=$(cat $1 | jq -r .groupName)
    #Retrieve User CRN
    user_crn=$(cdp iam get-user | jq -r .user.crn)
    #group_crn=$(cdp iam list-groups --group-names $group_name | jq -r .groups[0].crn)
fi


env_crn=$(cdp environments describe-environment --environment-name $envName | jq -r .environment.crn)

DATA_MSI_ID=$(az identity list -g $resourcegroup --query "[?name=='${dataMSI}']" | jq -r '.[0].id' | sed -e "s|resourcegroup|resourceGroup|g" )
RANGER_MSI_ID=$(az identity list -g $resourcegroup --query "[?name=='${rangerMSI}']" | jq -r '.[0].id' | sed -e "s|resourcegroup|resourceGroup|g" )
#ASSUMER_MSI_ID=$(az identity list -g $resourcegroup --query "[?name=='$resourcegroup-AssumerIdentity']" | jq -r '.[0].id' | sed -e "s|resourcegroup|resourceGroup|g" )


if [[ "$mapping" == "no" ]]
then
  cdp environments set-id-broker-mappings --environment-name ${envName} \
  --data-access-role ${DATA_MSI_ID} --ranger-audit-role "${RANGER_MSI_ID}" \
  --ranger-cloud-access-authorizer-role  "${RANGER_MSI_ID}" --set-empty-mappings

else
  cdp environments set-id-broker-mappings --environment-name ${envName} \
  --data-access-role ${DATA_MSI_ID} --ranger-audit-role "${RANGER_MSI_ID}" \
  --ranger-cloud-access-authorizer-role  "${RANGER_MSI_ID}" --no-set-empty-mappings \
  --mappings accessorCrn=${user_crn},role=${DATA_MSI_ID}

fi
