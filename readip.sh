#!/bin/bash

tr -d '\r' < inventory.ini > inventory2.ini
declare -a IPS2=()
n=0
while IFS= read -r line; do
   n=$(( n+1 ))
   IPS2+=("$line")
   if [ $n -eq 4 ]; then
       break
   fi
done < inventory2.ini

IPS=("${IPS2[@]:1}")

for i in ${IPS[@]}; do
    echo $i
done


cp -rfp kubespray/inventory/sample kubespray/inventory/mycluster
CONFIG_FILE=kubespray/inventory/mycluster/hosts.yaml python3 kubespray/contrib/inventory_builder/inventory.py ${IPS[@]}

sleep 3

rm -r inventory2.ini