#!/bin/bash

echo 'TEMP STUFF'
cd /
git clone packer-build-tasks output-manifest
#cd output-manifest
#ls -al
#cd ..

echo 'List root directory content'
ls -al

echo 'Copy secrets to packer template directory'
cp secrets/packer-secrets.json packer-templates/vhd-disk/packer-secrets.json

echo 'Change to packer template directory'
cd packer-templates/vhd-disk

echo 'List packer template directory content'
ls -al

echo 'Start packer validate'
packer validate -var-file="variables.json" -var-file="packer-secrets.json" windows.json

#echo 'start packer build'
#packer build -var-file="variables.json" -var-file="packer-secrets.json" windows.json