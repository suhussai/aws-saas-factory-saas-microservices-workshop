#!/bin/bash -xe

# screen -S s1 # new
# screen -x s1 # attach

# NOTE:
# remember to disable managed credentials for cloud9 before running!

rm -vf ${HOME}/.aws/credentials
# aws cloud9 update-environment  --environment-id $C9_PID --managed-credentials-action DISABLE

cd ~/environment/aws-saas-factory-saas-microservices-workshop
./setup.sh

cd ~/environment/aws-saas-factory-saas-microservices-workshop/standalone-eks-stack
./deploy-cluster.sh

kubectl get namespaces

cd ~/environment/aws-saas-factory-saas-microservices-workshop
./deploy.sh

kubectl get namespaces

aws cognito-idp list-user-pools --max-results 20 --query 'UserPools[?Name==`saas-microservices-workshop-user-pool`]'

cd ~/environment/aws-saas-factory-saas-microservices-workshop
npx cdk deploy PoolBasicStack --parameters PoolBasicStack:mode="product"

aws dynamodb describe-table --table-name "SaaSMicroservices-Products"

kubectl describe serviceaccount product-service-account

ROLE_NAME=$(kubectl get sa product-service-account \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' \
    | awk -F: '{print $NF}' | awk -F/ '{print $NF}'
    )
aws iam get-role --role-name $ROLE_NAME

RESP=$(aws iam list-role-policies --role-name $ROLE_NAME)
POLICY_NAME=$(echo "${RESP}" | jq -r '.PolicyNames[0]')
aws iam get-role-policy --role-name $ROLE_NAME --policy-name $POLICY_NAME

kubectl describe pod -l app=product-app

kubectl describe service product-service

kubectl describe virtualservice product-vs 

cd ~/environment/aws-saas-factory-saas-microservices-workshop
source ./scripts/set-environment-variables.sh
RESP=$(curl -k --silent --location --request POST "${LB_HOSTNAME}/products" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_A}" \
        --header 'Content-Type: application/json' \
        --data-raw "{
    \"name\": \"product a\",
    \"description\": \"this the first product\",
    \"price\": \"12.99\"
}")
PRODUCT_ID=$(echo "${RESP}" | jq -r '.product.product_id')
curl -k --silent --location --request GET "${LB_HOSTNAME}/products/${PRODUCT_ID}" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_A}" | jq

cd ~/environment/aws-saas-factory-saas-microservices-workshop/scripts/testing
python3 lab1_updates.py

cd ~/environment/aws-saas-factory-saas-microservices-workshop
./scripts/clean-single-tenant-product.sh
npx cdk deploy PoolBasicStack --parameters PoolBasicStack:mode="product"

cd ~/environment/aws-saas-factory-saas-microservices-workshop
cat ./tmp/Sample_JWTs.txt

kubectl get namespaces

kubectl get all -n basic-pool

aws dynamodb describe-table --table-name "SaaSMicroservices-Products-basic-pool"

curl -k --silent --location --request POST "${LB_HOSTNAME}/products" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_A}" \
        --header 'Content-Type: application/json' \
        --data-raw "{
    \"name\": \"tenant-a product\",
    \"description\": \"this the first product for tenant-a\",
    \"price\": \"12.99\"
}" | jq
curl -k --silent --location --request GET "${LB_HOSTNAME}/products" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_A}" | jq

curl -k --silent --location --request POST "${LB_HOSTNAME}/products" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_D}" \
        --header 'Content-Type: application/json' \
        --data-raw "{
    \"name\": \"tenant-d product\",
    \"description\": \"this the first product for tenant-d\",
    \"price\": \"99.99\"
}" | jq
curl -k --silent --location --request GET "${LB_HOSTNAME}/products" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_D}" | jq

cd ~/environment/aws-saas-factory-saas-microservices-workshop/scripts/testing
python3 lab2_updates_break.py

cd ~/environment/aws-saas-factory-saas-microservices-workshop
npx cdk deploy PoolBasicStack --parameters PoolBasicStack:mode="product"

curl -k --silent --location --request GET "${LB_HOSTNAME}/products" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_D}" | jq

cd ~/environment/aws-saas-factory-saas-microservices-workshop
npx cdk deploy TokenVendorStack

cd ~/environment/aws-saas-factory-saas-microservices-workshop/scripts/testing
python3 lab2_updates_fix.py

cd ~/environment/aws-saas-factory-saas-microservices-workshop
npx cdk deploy PoolBasicStack --parameters PoolBasicStack:mode="product"

curl -k --silent --location --request GET "${LB_HOSTNAME}/products" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_D}" | jq

kubectl logs -n basic-pool -l app=product-app --tail 2

cd ~/environment/aws-saas-factory-saas-microservices-workshop/scripts/testing
python3 lab2_updates_unbreak.py

cd ~/environment/aws-saas-factory-saas-microservices-workshop
npx cdk deploy PoolBasicStack --parameters PoolBasicStack:mode="product"

curl -k --silent --location --request GET "${LB_HOSTNAME}/products" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_D}" | jq

cd ~/environment/aws-saas-factory-saas-microservices-workshop/scripts/testing
python3 lab3_updates.py

cd ~/environment/aws-saas-factory-saas-microservices-workshop
npx cdk deploy PoolBasicStack --parameters PoolBasicStack:mode="all"

kubectl get all -n basic-pool
kubectl get vs -n basic-pool

RESP=$(curl -k --silent --location --request GET "${LB_HOSTNAME}/products" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_A}")
PRODUCT_ID=$(echo "${RESP}" | jq -r '.products[0].productId')
curl -k --silent --location --request POST "${LB_HOSTNAME}/orders" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_A}" \
        --header 'Content-Type: application/json' \
        --data-raw "{
    \"name\": \"Tenant-a Order\",
    \"description\": \"Tenant-a Order Description\",
    \"products\": [\"$PRODUCT_ID\"]
}" | jq

RESP=$(curl -k --silent --location --request GET "${LB_HOSTNAME}/products" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_D}")
PRODUCT_ID=$(echo "${RESP}" | jq -r '.products[0].productId')
curl -k --silent --location --request POST "${LB_HOSTNAME}/orders" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_D}" \
        --header 'Content-Type: application/json' \
        --data-raw "{
    \"name\": \"tenant-d Order\",
    \"description\": \"tenant-d Order Description\",
    \"products\": [\"$PRODUCT_ID\"]
}" | jq

kubectl logs -n basic-pool -l app=order-app --tail 6

kubectl logs -n basic-pool -l app=fulfillment-app --tail 4

cd ~/environment/aws-saas-factory-saas-microservices-workshop/scripts/testing
python3 lab4_updates_ingress.py

cd ~/environment/aws-saas-factory-saas-microservices-workshop
npx cdk deploy PoolBasicStack tenantCstack

kubectl -n istio-system get pods

kubectl -n istio-ingress get pods
kubectl -n istio-ingress get svc

kubectl -n tenant-c get all

kubectl -n basic-pool get all

kubectl describe namespace tenant-c
kubectl describe service product-service -n tenant-c

kubectl describe namespace basic-pool
kubectl describe service product-service -n basic-pool

kubectl -n tenant-c get vs product-vs \
    -o jsonpath='{.spec}' \
    | jq -r

kubectl -n basic-pool get vs product-vs \
    -o jsonpath='{.spec}' \
    | jq -r

RESP=$(curl -k --silent --location --request POST "${LB_HOSTNAME}/products" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_C}" \
        --header 'Content-Type: application/json' \
        --data-raw "{
    \"name\": \"tenant-c product\",
    \"description\": \"this the a product for tenant-c\",
    \"price\": \"1850.00\"
}")
PRODUCT_ID=$(echo "${RESP}" | jq -r '.product.product_id')
curl -k --silent --location --request POST "${LB_HOSTNAME}/orders" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_C}" \
        --header 'Content-Type: application/json' \
        --data-raw "{
    \"name\": \"Tenant-c order\",
    \"description\": \"Tenant-c order description\",
    \"products\": [\"$PRODUCT_ID\"]
}" | jq

kubectl logs -n tenant-c -l app=order-app --tail 10

RESP=$(curl -k --silent --location --request POST "${LB_HOSTNAME}/products" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_A}" \
        --header 'Content-Type: application/json' \
        --data-raw "{
    \"name\": \"tenant-a product\",
    \"description\": \"this the a product for tenant-a\",
    \"price\": \"19.99\"
}")
PRODUCT_ID=$(echo "${RESP}" | jq -r '.product.product_id')
curl -k --silent --location --request POST "${LB_HOSTNAME}/orders" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_A}" \
        --header 'Content-Type: application/json' \
        --data-raw "{
    \"name\": \"Tenant-a order\",
    \"description\": \"Tenant-a order description\",
    \"products\": [\"$PRODUCT_ID\"]
}" | jq

kubectl logs -n basic-pool -l app=order-app --tail 10

cd ~/environment/aws-saas-factory-saas-microservices-workshop/scripts/testing
python3 lab4_updates_service_to_service.py

cd ~/environment/aws-saas-factory-saas-microservices-workshop
npx cdk deploy PoolBasicStack tenantBstack

kubectl describe ns tenant-b

kubectl -n tenant-b get all

kubectl -n basic-pool get vs fulfillment-vs \
    -o jsonpath='{.spec}' \
    | jq -r

RESP=$(curl -k --silent --location --request POST "${LB_HOSTNAME}/products" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_B}" \
        --header 'Content-Type: application/json' \
        --data-raw "{
    \"name\": \"tenant-b product\",
    \"description\": \"this the a product for tenant-b\",
    \"price\": \"10.99\"
}")
PRODUCT_ID=$(echo "${RESP}" | jq -r '.product.product_id')
curl -k --silent --location --request POST "${LB_HOSTNAME}/orders" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_B}" \
        --header 'Content-Type: application/json' \
        --data-raw "{
    \"name\": \"Tenant-b order\",
    \"description\": \"Tenant-b order description\",
    \"products\": [\"$PRODUCT_ID\"]
}" | jq

RESP=$(curl -k --silent --location --request POST "${LB_HOSTNAME}/products" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_A}" \
        --header 'Content-Type: application/json' \
        --data-raw "{
    \"name\": \"tenant-a product\",
    \"description\": \"this the a product for tenant-a\",
    \"price\": \"49.99\"
}")
PRODUCT_ID=$(echo "${RESP}" | jq -r '.product.product_id')
curl -k --silent --location --request POST "${LB_HOSTNAME}/orders" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_A}" \
        --header 'Content-Type: application/json' \
        --data-raw "{
    \"name\": \"Tenant-a order\",
    \"description\": \"Tenant-a order description\",
    \"products\": [\"$PRODUCT_ID\"]
}" | jq

kubectl logs -n basic-pool -l app=order-app --tail 10

kubectl logs -n tenant-b -l app=fulfillment-app --tail 10

kubectl logs -n basic-pool -l app=fulfillment-app --tail 10

cd ~/environment/aws-saas-factory-saas-microservices-workshop/scripts/testing
python3 lab5_updates_logs.py

cd ~/environment/aws-saas-factory-saas-microservices-workshop
npx cdk deploy --all

kubectl get pods -n basic-pool

RESP=$(curl -k --silent --location --request GET "${LB_HOSTNAME}/products" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_A}")
PRODUCT_ID=$(echo "${RESP}" | jq -r '.products[0].productId')
curl -k --silent --location --request POST "${LB_HOSTNAME}/orders" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_A}" \
        --header 'Content-Type: application/json' \
        --data-raw "{
    \"name\": \"Tenant-a Order\",
    \"description\": \"Tenant-a Order Description\",
    \"products\": [\"$PRODUCT_ID\"]
}" | jq

cd ~/environment/aws-saas-factory-saas-microservices-workshop/scripts/testing
python3 lab5_updates_xray.py

cd ~/environment/aws-saas-factory-saas-microservices-workshop
npx cdk deploy --all

cd ~/environment/aws-saas-factory-saas-microservices-workshop
./scripts/run-queries.sh

cd ~/environment/aws-saas-factory-saas-microservices-workshop
./scripts/run-queries.sh
