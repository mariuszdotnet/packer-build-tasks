#!/bin/bash

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

echo 'start packer build'
#packer build -var-file="variables.json" -var-file="packer-secrets.json" windows.json
# remove build

echo 'Start pushing packer manifest file to output branch'
cd ../../
git clone packer-build-output output-manifest

echo 'Copy manifest file to output directory'
cp packer-templates/vhd-disk/manifest.json output-manifest/manifest.json
cd output-manifest

# TODO: TESTING CODE DELETE WHEN DONE
tempFileString=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
touch tempfile.txt
echo $tempFileString > tempfile.txt

git config --global user.email "nobody@concourse-ci.org"
git config --global user.name "Concourse"
git add .
git commit -m "Published packer manifest file"