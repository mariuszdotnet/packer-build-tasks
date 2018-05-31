#!/bin/bash 
### VM image file cross-region distrubution and image creation
### Date: May 11, 2018

# Copy 'manifest.json' into working directory 'packer-build-tasks'
echo 'Copy manifestjson into packer-build-tasks'
cp packer-build-output/manifest.json packer-build-tasks/manifest.json

echo 'Change to packer template directory and list content'
cd packer-build-tasks
ls -al

# Set all environment variables from image_copy_config.json, manifest.json and TASK ENV variables
echo 'Load all required environment variables for VHD copy to desired subscription in targer region'

config_file='image_copy_config.json'
servicePrincipal=$servicePrincipal
servicePrincipalPwd=$servicePrincipalPwd

# Set source variables
source_region_json=$(jq --arg regionLocation $regionLocation '.region_location[] | select(any(.location; . == $regionLocation))' $config_file)
vhd_name=$(echo $source_region_json | jq -r '.vhd_uri')
subscriptionId=$(echo $source_region_json | jq -r '.subscription_id')
vhd_storage_account_rg=$(echo $source_region_json | jq -r '.vhd_storage_account_rg')
vhd_storage_account_name=$(echo $source_region_json | jq -r '.vhd_storage_account_name')
vhd_storage_container=$(echo $source_region_json | jq -r '.vhd_storage_container')

#Authenticate with service principal
echo "Authenticating to Azure with service principal $servicePrincipal"
#echo "and pwd $servicePrincipalPwd"
az login --service-principal -u "$servicePrincipal" --password "$servicePrincipalPwd" --tenant "microsoft.onmicrosoft.com"
echo 'Azure login completed'
az account set --subscription $subscriptionId

#Get source storage account access keys
sourceStorageAccountKey=$(az storage account keys list -g $vhd_storage_account_rg --account-name $vhd_storage_account_name --query "[:1].value" -o tsv)

#Iterate over all subscription strorage accounts in a region.  Copy VND and create image
#mk=$(jq --arg regionLocation 'eastus2' '.region_location[] | select(any(.location; . == $regionLocation))' manifest.json)
target_region_json=$(jq --arg regionLocation $regionLocation '.region_location[] | select(any(.location; . == $regionLocation))' $config_file)
subscriptions=$(echo $target_region_json | jq -r '.subscription')

for row in $(echo $subscriptions | jq -r '.[] | @base64'); do
    _jq() {
            echo $row | base64 -d | jq -r ${1}
    }

    #Set target region location specific variables for VHD copy  
    dest_vhd_storage_container=echo $(_jq '.vhd_storage_container')
    dest_subscriptionId=echo $(_jq '.subscription_id')
    dest_vhd_storage_account_rg=echo $(_jq '.vhd_storage_account_rg')
    dest_vhd_storage_account_name=echo $(_jq '.vhd_storage_account_name')
    dest_vhd_uri=echo $(_jq '.vhd_uri')

    #Get target storage account access keys
    targetStorageAccountKey=$(az storage account keys list -g $dest_vhd_storage_account_rg --account-name $dest_vhd_storage_account_name --query "[:1].value" -o tsv)
done