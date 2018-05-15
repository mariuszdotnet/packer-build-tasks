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

jq . manifest.json

servicePrincipal=$servicePrincipal
servicePrincipalPwd=$servicePrincipalPwd
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