#!/bin/bash 
### VM image file cross-region distrubution and image creation
### Date: May 11, 2018
#Get the service principal creds from input file and set as variables
#For servicePrincipal value, use the App ID URI for the AAD service principal object
#servicePrincipal='https://microsoft.onmicrosoft.com/84083a4c-7291-441d-8bf0-20666c6ec7b9'
#or App ID '9106aca3-bbd1-4025-9443-ed691f45619e'

subscriptionId='0f8b9904-2b81-4c06-b9b8-83bd9be58cde'
vhd_uri='https://imagesrepoglobal2cac.blob.core.windows.net/images/mdimage01_OsDisk_1_9aabd581bd334a3e8c31934c6eef4209.vhd'
vhd_storage_account_rg='ImagesRepo'
vhd_storage_account_name='imagesrepoglobal2cac'
vhd_storage_container='images'
dest_subscriptionId='0f8b9904-2b81-4c06-b9b8-83bd9be58cde'
dest_vhd_storage_account_rg='ImagesRepo'
dest_vhd_storage_account_name='imagesrepoglobal2'
dest_vhd_uri='mdimage01_OsDisk_1_9_101.vhd'
dest_image_rg='ImagesRepo'
dest_image_name='MM_MK_Test3'
dest_image_os_type='Windows'
location='eastus2'
#
#Authenticate with service principal
echo "Authenticating to Azure with service principal $servicePrincipal"
echo "and pwd $servicePrincipalPwd"
az login --service-principal -u "$servicePrincipal" --password "$servicePrincipalPwd" --tenant "microsoft.onmicrosoft.com"
echo 'Azure login completed'
az account set --subscription $subscriptionId
#
#TODO: Confirm if access keys are even needed - appears to work without
#Get storage account access keys
sourceStorageAccountKey=$(az storage account keys list -g $vhd_storage_account_rg --account-name $vhd_storage_account_name --query "[:1].value" -o tsv)
targetStorageAccountKey=$(az storage account keys list -g $dest_vhd_storage_account_rg --account-name $dest_vhd_storage_account_name --query "[:1].value" -o tsv)
#
#Start blob copy
dest_image_src_URI="https://$dest_vhd_storage_account_name.blob.core.windows.net/$vhd_storage_container/$dest_vhd_uri"
blobCopyStatus=$(az storage blob show --container-name $vhd_storage_container -n $dest_vhd_uri --account-name $dest_vhd_storage_account_name --query "properties.copy.status")
echo "Current blob copy status: $blobCopyStatus"
#Blob statuses: "pending", "success"
#Check if copy operation in progress
if [ $blobCopyStatus == "\"pending\"" ]
then
  echo "Copy operation already in progress to $dest_image_src_URI. Switching to monitoring"
else
  echo "Starting blob copy operation from $vhd_uri to $dest_image_src_URI"
  copyId=$(az storage blob copy start --source-uri $vhd_uri --destination-blob $dest_vhd_uri --destination-container $vhd_storage_container --account-name $dest_vhd_storage_account_name )
    #Appears that storage account key is not required for auth
    #az storage blob copy start --source-uri $vhd_uri --destination-blob $dest_vhd_uri --destination-container $vhd_storage_container --account-name $dest_vhd_storage_account_name --account-key $targetStorageAccountKey --source-account-key $sourceStorageAccountKey
fi

#Wait for blob copy to complete
while [  $blobCopyStatus != "\"success\"" ]
do
    echo "Blob copy in progress. Bytes copied $(az storage blob show --container-name $vhd_storage_container -n $dest_vhd_uri --account-name $dest_vhd_storage_account_name --query "properties.copy.progress")"
    sleep 60
    blobCopyStatus=$(az storage blob show --container-name $vhd_storage_container -n $dest_vhd_uri --account-name $dest_vhd_storage_account_name --query "properties.copy.status")
done

echo "Blob copy completed"     
az storage blob show --container-name $vhd_storage_container -n $dest_vhd_uri --account-name $dest_vhd_storage_account_name --query "properties.copy.status"

##IMAGE
#Create image
echo "Creating image $dest_image_name in region $location from VHD $dest_image_src_URI"
az account set --subscription $dest_subscriptionId
imageCopyOp=$(az image create -g $dest_image_rg -n $dest_image_name -l $location --os-type $dest_image_os_type --source $dest_image_src_URI)
echo "Image copy operation status:"
echo $imageCopyOp

echo "Script finished"