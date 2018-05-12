#!/bin/bash

echo 'List root directory content'
ls -al
cp secrets/packer-secrets.json packer-templates/vhd-disk/packer-secrets.json
cd packer-templates/vhd-disk
ls -al
packer validate -var-file="variables.json" -var-file="packer-secrets.json" windows.json

#packer validate  -var-file="variables.json" windows2016.json
#packer build  -var-file="variables.json" windows2016.json
