#!/bin/bash

cd packer-build-output
ls -al
cat manifest.json | jq .builds[0].artifact_id