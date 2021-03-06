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
echo 'Load all required environment variables for VHD copy to desired region'

config_file='image_copy_config.json'
servicePrincipal=$servicePrincipal
servicePrincipalPwd=$servicePrincipalPwd

# Set source location variables
vhd_uri=$(jq -r '.builds[].artifact_id' manifest.json)
vhd_name=${vhd_uri#*system/}
subscriptionId=$(jq -r .source_location.subscription_id $config_file)
vhd_storage_account_rg=$(jq -r .source_location.vhd_storage_account_rg $config_file)
vhd_storage_account_name=$(jq -r .source_location.vhd_storage_account_name $config_file)
vhd_storage_container=$(jq -r .source_location.vhd_storage_container $config_file)

# Set target region location specific variables for VHD copy
target_region_json=$(jq --arg regionLocation $regionLocation '.region_location[] | select(any(.location; . == $regionLocation))' $config_file)
## TODO: Check that location is actually used, REMOVE ME!
location=$(echo $target_region_json | jq -r '.location')
dest_vhd_storage_container=$(echo $target_region_json | jq -r '.vhd_storage_container')
dest_subscriptionId=$(echo $target_region_json | jq -r '.subscription_id')
dest_vhd_storage_account_rg=$(echo $target_region_json | jq -r '.vhd_storage_account_rg')
dest_vhd_storage_account_name=$(echo $target_region_json | jq -r '.vhd_storage_account_name')
dest_vhd_uri=$(echo $target_region_json | jq -r '.vhd_uri')

#Authenticate with service principal
echo "Authenticating to Azure with service principal $servicePrincipal"
#echo "and pwd $servicePrincipalPwd"
az login --service-principal -u "$servicePrincipal" --password "$servicePrincipalPwd" --tenant "microsoft.onmicrosoft.com"
echo 'Azure login completed'
az account set --subscription $subscriptionId

#Get storage account access keys

sourceStorageAccountKey=$(az storage account keys list -g $vhd_storage_account_rg --account-name $vhd_storage_account_name --query "[:1].value" -o tsv)
targetStorageAccountKey=$(az storage account keys list -g $dest_vhd_storage_account_rg --account-name $dest_vhd_storage_account_name --query "[:1].value" -o tsv)
#Start blob copy

dest_image_src_URI="https://$dest_vhd_storage_account_name.blob.core.windows.net/$vhd_storage_container/$dest_vhd_uri"
blobCopyStatus=$(az storage blob show --container-name $dest_vhd_storage_container -n $dest_vhd_uri --account-name $dest_vhd_storage_account_name --query "properties.copy.status")
echo "Current blob copy status: $blobCopyStatus"
#Blob statuses: "pending", "success"
#Check if copy operation in progress
if [[ $blobCopyStatus == "\"pending\"" ]]
then
  echo "Copy operation already in progress to $dest_image_src_URI. Switching to monitoring"
else
  echo "Starting blob copy operation from $vhd_uri to $dest_image_src_URI"
  copyId=$(az storage blob copy start --source-account-name $vhd_storage_account_name --source-blob $vhd_name --source-container $vhd_storage_container --source-account-key $sourceStorageAccountKey --account-name $dest_vhd_storage_account_name --destination-blob $dest_vhd_uri --destination-container $dest_vhd_storage_container --account-key $targetStorageAccountKey)
fi

#Wait for blob copy to complete
while [[ $blobCopyStatus != "\"success\"" ]]
do
    echo "Blob copy in progress. Bytes copied $(az storage blob show --container-name $dest_vhd_storage_container -n $dest_vhd_uri --account-name $dest_vhd_storage_account_name --query "properties.copy.progress")"
    sleep 10
    blobCopyStatus=$(az storage blob show --container-name $dest_vhd_storage_container -n $dest_vhd_uri --account-name $dest_vhd_storage_account_name --query "properties.copy.status")
done

echo "Blob copy completed"     
az storage blob show --container-name $dest_vhd_storage_container -n $dest_vhd_uri --account-name $dest_vhd_storage_account_name --query "properties.copy.status"
