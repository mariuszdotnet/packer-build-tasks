#!/bin/bash

#echo 'List root directory content'
#ls -al

servicePrincipal='9106aca3-bbd1-4025-9443-ed691f45619e'
servicePrincipalPwd='GIO88YTYUrOG0G7ne8Cq94yez1VBB3bwTksqNUu7wyo='
subscriptionId='0f8b9904-2b81-4c06-b9b8-83bd9be58cde'
az login --service-principal -u $servicePrincipal --password $servicePrincipalPwd --tenant "microsoft.onmicrosoft.com"
az account set --subscription $subscriptionId