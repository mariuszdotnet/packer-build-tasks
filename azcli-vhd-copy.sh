#!/bin/bash

cd packer-build-output
ls -al
vhd_uri=$(cat manifest.json | jq .builds[0].artifact_id)
echo $vhd_uri