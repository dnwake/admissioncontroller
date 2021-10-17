#!/bin/bash

## Cleanup
kubectl delete validatingwebhookconfiguration deployment-validation pod-validation
kubectl delete mutatingwebhookconfiguration pod-mutation
kubectl delete namespace special
kubectl delete service admission-server
kubectl delete pod webserver
kubectl delete deployment admission-server
kubectl delete secret admission-tls

echo "Creating certificates"
rm -fr certs
mkdir certs
openssl req -nodes -new -x509 -keyout certs/ca.key -out certs/ca.crt -subj "/CN=Admission Controller Demo" 
openssl genrsa -out certs/admission-tls.key 2048
openssl req -new -key certs/admission-tls.key -subj "/CN=admission-server.default.svc" -config openssl_config.txt | openssl x509 -req -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial -out certs/admission-tls.crt -extensions v3_req -extfile openssl_config.txt

echo "Creating k8s Secret"
kubectl create secret tls admission-tls \
    --cert "certs/admission-tls.crt" \
    --key "certs/admission-tls.key"

echo "Creating k8s admission deployment"
kubectl create -f deployment.yaml

echo "Creating k8s webhooks for demo"
CA_BUNDLE=$(cat certs/ca.crt | base64 | tr -d '\n')

sed -e 's@${CA_BUNDLE}@'"$CA_BUNDLE"'@g' <"webhooks.yaml" | kubectl create -f -

echo "WAITING FOR SERVER TO START"
kubectl rollout status deployment admission-server

kubectl create  -f pods/01_fail_pod_creation_test.yaml


