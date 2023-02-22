#!/bin/bash
set -o nounset

display_usage() {
    echo "
Usage:
    $(basename "$0") [--help or -h] <cdp_parameter>
Description:
    Launches a CDP Azure environment
Arguments:
    cdp_parameter:                CDP datalakeName Parameter file in json
    --help or -h:   displays this help"

}

if [[ ( ${1:-x} == "--help") ||  ${1:-x} == "-h" ]]
then
    display_usage
    exit 0
fi


# Check the numbers of arguments
if [  $# -lt 1 ]
then
    echo "Not enough arguments!" >&2
    display_usage
    exit 1
fi

if [  $# -gt 1 ]
then
    echo "Too many arguments!" >&2
    display_usage
    exit 1
fi

datalakeName=$(cat $1 | jq -r .datalakeName)
envName=$(cat $1 | jq -r .environmentName)
resourcegroup=$(cat $1 | jq -r .resourceGroupName)
storageURL=$(cat $1 | jq -r .cloudProviderConfiguration.storageLocation)
scale=$(cat $1 | jq -r .scale)
runtime=$(cat $1 | jq -r .runtime)
assumerMSI=$(cat $1 | jq -r .cloudProviderConfiguration.assumeManagedID)


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


env_crn=$(cdp environments describe-environment --environment-name $envName | jq -r .environment.crn)

ASSUMER_MSI_ID=$(az identity list -g $resourcegroup --query "[?name=='${assumerMSI}']" | jq -r '.[0].id' | sed -e "s|resourcegroup|resourceGroup|g" )


cdp datalake create-azure-datalake --datalake-name ${datalakeName} --environment-name ${envName} \
--cloud-provider-configuration storageLocation="${storageURL}",managedIdentity="${ASSUMER_MSI_ID}" --scale "${scale}" \
--runtime "${runtime}" --tags ${flattened_tags}

sleep 60

status=$(cdp datalake describe-datalake --datalake-name ${datalakeName} | jq -r .datalake.status)
while [ $status != "RUNNING" ]
do
  # Communicate that we're waiting.
  echo " Status: $status"
  sleep 30
  # Re run the command.
  status=$(cdp datalake describe-datalake --datalake-name ${datalakeName} | jq -r .datalake.status)
done

# Environment Creation has finished.
echo "Datalake is ${status}"

#Sync ID Broker with Datalake
sleep 10
cdp environments sync-id-broker-mappings --environment-name ${envName}

#cdp datahub create-azure-cluster --cluster-name ${envName}-cod --cluster-definition-name "Operational Database for Azure" --environment-name ${envName}
