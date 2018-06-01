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
vhd_uri="https://$vhd_storage_account_name.blob.core.windows.net/vhd_storage_container/$vhd_name"

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
    dest_vhd_storage_container=$(_jq '.vhd_storage_container')
    dest_vhd_storage_account_rg=$(_jq '.vhd_storage_account_rg')
    dest_vhd_storage_account_name=$(_jq '.vhd_storage_account_name')
    dest_vhd_uri=$(_jq '.vhd_uri')

    #Set target region location specific variable for image creation
    dest_subscriptionId=$(_jq '.subscription_id')
    dest_image_rg=$(_jq '.image_rg')
    dest_image_name=$(_jq '.image_name')
    dest_image_os_type=$(_jq '.image_os_type')
    location=$(_jq '.location')

    az account set --subscription $dest_subscriptionId

    #Get target storage account access keys
    targetStorageAccountKey=$(az storage account keys list -g $dest_vhd_storage_account_rg --account-name $dest_vhd_storage_account_name --query "[:1].value" -o tsv)

    #Start VHD copy within region across subscriptions
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

    #Create image
    echo "Creating image $dest_image_name in region $location from VHD $dest_image_src_URI"
    az account set --subscription $dest_subscriptionId
    imageCopyOp=$(az image create -g $dest_image_rg -n $dest_image_name -l $location --os-type $dest_image_os_type --source $dest_image_src_URI)
    echo "Image copy operation status:"
    echo $imageCopyOp

    echo "Script finished"
done