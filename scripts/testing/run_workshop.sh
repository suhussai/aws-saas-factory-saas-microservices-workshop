#!/bin/bash -xe

# screen -S s1 # new
# screen -x s1 # attach

# NOTE:
# remember to disable managed credentials for cloud9 before running!

rm -vf ${HOME}/.aws/credentials

### START ./1-introduction/2-environment-setup/2-on-your-own/p7-install-cloud9-tools.en.md #
cd ~/environment/aws-saas-factory-saas-microservices-workshop
./setup.sh

### END ./1-introduction/2-environment-setup/2-on-your-own/p7-install-cloud9-tools.en.md #

### START ./1-introduction/2-environment-setup/2-on-your-own/p8-create-cluster.en.md #
cd ~/environment/aws-saas-factory-saas-microservices-workshop/standalone-eks-stack
./deploy-cluster.sh

kubectl get namespaces

### END ./1-introduction/2-environment-setup/2-on-your-own/p8-create-cluster.en.md #

### START ./1-introduction/2-environment-setup/2-on-your-own/p9-deploy-base.en.md #
cd ~/environment/aws-saas-factory-saas-microservices-workshop
./deploy.sh

kubectl get namespaces

aws cognito-idp list-user-pools --max-results 20 --query 'UserPools[?Name==`saas-microservices-workshop-user-pool`]'

### END ./1-introduction/2-environment-setup/2-on-your-own/p9-deploy-base.en.md #

### START ./2-Lab1/2-1-baseline-product-microservice/index.en.md #
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

### END ./2-Lab1/2-1-baseline-product-microservice/index.en.md #

cd ~/environment/aws-saas-factory-saas-microservices-workshop/scripts/testing
python3 lab1_updates.py

### START ./2-Lab1/2-4-deploy-the-microservice/index.en.md #
cd ~/environment/aws-saas-factory-saas-microservices-workshop
./scripts/clean-single-tenant-product.sh
npx cdk deploy PoolBasicStack --parameters PoolBasicStack:mode="product"

cd ~/environment/aws-saas-factory-saas-microservices-workshop
cat ./tmp/Sample_JWTs.txt

kubectl get namespaces

kubectl get all -n basic-pool

aws dynamodb describe-table --table-name "SaaSMicroservices-Products-basic-pool"

### END ./2-Lab1/2-4-deploy-the-microservice/index.en.md #

### START ./2-Lab1/2-5-test-the-microservice/index.en.md #
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

### END ./2-Lab1/2-5-test-the-microservice/index.en.md #

cd ~/environment/aws-saas-factory-saas-microservices-workshop/scripts/testing
python3 lab2_updates_break.py

### START ./3-Lab2/3-1-app-bug/index.en.md #
cd ~/environment/aws-saas-factory-saas-microservices-workshop
npx cdk deploy PoolBasicStack --parameters PoolBasicStack:mode="product"

curl -k --silent --location --request GET "${LB_HOSTNAME}/products" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_D}" | jq

### END ./3-Lab2/3-1-app-bug/index.en.md #

### START ./3-Lab2/3-2-token-vendor-sidecar/index.en.md #
cd ~/environment/aws-saas-factory-saas-microservices-workshop
npx cdk deploy TokenVendorStack

### END ./3-Lab2/3-2-token-vendor-sidecar/index.en.md #

cd ~/environment/aws-saas-factory-saas-microservices-workshop/scripts/testing
python3 lab2_updates_fix.py

### START ./3-Lab2/3-3-modifying-the-product-stack/index.en.md #
cd ~/environment/aws-saas-factory-saas-microservices-workshop
npx cdk deploy PoolBasicStack --parameters PoolBasicStack:mode="product"

### END ./3-Lab2/3-3-modifying-the-product-stack/index.en.md #

### START ./3-Lab2/3-4-test-isolation/index.en.md #
curl -k --silent --location --request GET "${LB_HOSTNAME}/products" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_D}" | jq

kubectl logs -n basic-pool -l app=product-app --tail 2

### END ./3-Lab2/3-4-test-isolation/index.en.md #

cd ~/environment/aws-saas-factory-saas-microservices-workshop/scripts/testing
python3 lab2_updates_unbreak.py

### START ./3-Lab2/3-5-unbreak-the-service/index.en.md #
cd ~/environment/aws-saas-factory-saas-microservices-workshop
npx cdk deploy PoolBasicStack --parameters PoolBasicStack:mode="product"

curl -k --silent --location --request GET "${LB_HOSTNAME}/products" \
        --header "Host: ${HOST}" \
        --header "Authorization: Bearer ${JWT_TOKEN_TENANT_D}" | jq

### END ./3-Lab2/3-5-unbreak-the-service/index.en.md #

cd ~/environment/aws-saas-factory-saas-microservices-workshop/scripts/testing
python3 lab3_updates.py

### START ./4-Lab3/4-1-introducing-library/index.en.md #

cd ~/environment/aws-saas-factory-saas-microservices-workshop
npx cdk deploy PoolBasicStack --parameters PoolBasicStack:mode="all"

### END ./4-Lab3/4-1-introducing-library/index.en.md #

### START ./4-Lab3/4-3-testing/index.en.md #
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

### END ./4-Lab3/4-3-testing/index.en.md #

cd ~/environment/aws-saas-factory-saas-microservices-workshop/scripts/testing
python3 lab4_updates_ingress.py

### START ./5-Lab4/5-1-Ingress-routing/5-1-2-Ingress-routing-deploy/index.en.md #
cd ~/environment/aws-saas-factory-saas-microservices-workshop
npx cdk deploy PoolBasicStack tenantCstack

kubectl -n istio-system get pods

kubectl -n istio-ingress get pods
kubectl -n istio-ingress get svc

### END ./5-Lab4/5-1-Ingress-routing/5-1-2-Ingress-routing-deploy/index.en.md #

### START ./5-Lab4/5-1-Ingress-routing/5-1-3-Ingress-routing-review/index.en.md #
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

### END ./5-Lab4/5-1-Ingress-routing/5-1-3-Ingress-routing-review/index.en.md #

### START ./5-Lab4/5-1-Ingress-routing/5-1-4-Ingress-routing-testing/index.en.md #
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

### END ./5-Lab4/5-1-Ingress-routing/5-1-4-Ingress-routing-testing/index.en.md #

cd ~/environment/aws-saas-factory-saas-microservices-workshop/scripts/testing
python3 lab4_updates_service_to_service.py

### START ./5-Lab4/5-2-service-to-service-routing/5-2-2-service-to-service-routing-deploy/index.en.md #
cd ~/environment/aws-saas-factory-saas-microservices-workshop
npx cdk deploy PoolBasicStack tenantBstack

kubectl describe ns tenant-b

kubectl -n tenant-b get all

kubectl -n basic-pool get vs fulfillment-vs \
    -o jsonpath='{.spec}' \
    | jq -r

### END ./5-Lab4/5-2-service-to-service-routing/5-2-2-service-to-service-routing-deploy/index.en.md #

### START ./5-Lab4/5-2-service-to-service-routing/5-2-3-service-to-service-routing-testing/index.en.md #
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

### END ./5-Lab4/5-2-service-to-service-routing/5-2-3-service-to-service-routing-testing/index.en.md #

cd ~/environment/aws-saas-factory-saas-microservices-workshop/scripts/testing
python3 lab5_updates_logs.py

### START ./6-Lab5/6-2-creating-tenant-aware-metrics-from-logs/index.en.md #
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

cd ~/environment/aws-saas-factory-saas-microservices-workshop
./scripts/run-queries.sh

### END ./6-Lab5/6-2-creating-tenant-aware-metrics-from-logs/index.en.md #

cd ~/environment/aws-saas-factory-saas-microservices-workshop/scripts/testing
python3 lab5_updates_xray.py

### START ./6-Lab5/6-3-tracing-with-aws-x-ray/index.en.md #
cd ~/environment/aws-saas-factory-saas-microservices-workshop
npx cdk deploy --all

cd ~/environment/aws-saas-factory-saas-microservices-workshop
./scripts/run-queries.sh

cd ~/environment/aws-saas-factory-saas-microservices-workshop
./scripts/run-queries.sh

### END ./6-Lab5/6-3-tracing-with-aws-x-ray/index.en.md #
