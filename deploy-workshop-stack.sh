#!/bin/bash -xe

echo "Starting cdk deploy..."
cd standalone-eks-stack
npm install
npx cdk bootstrap
npx --yes cdk deploy eksBlueprintStack/EKSStack \
    --require-approval never \
    --parameters EksBlueprintStack:createCloud9Instance=true

echo "Done cdk deploy!"