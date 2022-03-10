#!/bin/bash

####Preparing

echo '0: Load Registry credential'
kubectl create -f docker_secret.yaml 

sleep 2

echo '1.1: load PSQL configmap'
kubectl create -f postgres_configmap.yaml 

sleep 2

echo '1.2: Create storage for PSQL'
kubectl create -f postgres_storage.yaml 

sleep 2

echo '1.3: Deploy PSQL'
kubectl create -f postgres_dep.yaml


sleep 2

echo '1.4: Create network service for PSQL'

kubectl create -f postgres_service.yaml 


sleep 2 

####STAGE 2

echo '2.1: load APP configmap'
kubectl create -f app_configmap.yaml 

sleep 2 



echo '2.2: Create secret for APP'
kubectl create -f app_secret.yaml


sleep 2 

echo '2.3: Deploy APP'

kubectl create -f app_dep.yaml

echo '2.4: Create network service for PSQL'
mc
kubectl create -f app_service.yaml 

echo '2.5: Create Ingress conroller for APP'
kubectl apply -f app_ingress.yaml


