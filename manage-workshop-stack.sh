#!/bin/bash -xe

run_ssm_command() {
    TARGET_USER="$1"
    C9_PID="$2"
    SSM_COMMAND="$3"
    parameters=$(jq -n --arg cm "runuser -l \"$TARGET_USER\" -c \"$SSM_COMMAND\"" '{executionTimeout:["600"], commands: [$cm]}')
    # send ssm command to instance id in C9_PID
    sh_command_id=$(aws ssm send-command \
        --targets "Key=InstanceIds,Values=$C9_PID" \
        --document-name "AWS-RunShellScript" \
        --parameters "$parameters" \
        --timeout-seconds 600 \
        --comment "$(echo \"$SSM_COMMAND\" | cut -c1-100)" \
        --output text \
        --query "Command.CommandId")

    command_status="InProgress" # seed status var
    while [ "$command_status" == "InProgress" ]; do
        sleep 30
        command_invocation=$(aws ssm get-command-invocation \
            --command-id "$sh_command_id" \
            --instance-id "$C9_PID")
        echo -E "$command_invocation" | jq # for debugging purposes
        command_status=$(echo -E "$command_invocation" | jq -r '.Status')
    done
    [ "$command_status" != "Success" ] && (echo "failed executing $SSM_COMMAND : $command_status" && exit 1)
    echo "successfully completed execution!"
}

STACK_OPERATION=$(echo "$1" | tr '[:upper:]' '[:lower:]')
CLOUD9_INSTANCE_ID_PARAMETER_NAME="/saas-workshop/cloud9InstanceId"
GIT_REPO=$REPO_URL
GIT_BRANCH=$REPO_BRANCH_NAME

# TARGET_USER="ec2-user"
TARGET_USER="ubuntu"
corepack enable
corepack prepare yarn@stable --activate
npm install -g aws-cdk@2.91.0

cd standalone-eks-stack
yarn install
npx -y cdk bootstrap

if [[ "$STACK_OPERATION" == "create" || "$STACK_OPERATION" == "update" ]]; then
    echo "Starting cdk deploy..."
    npx cdk deploy SaaSWorkshopBootstrap \
        --require-approval never
    echo "Done cdk deploy!"

    if [[ "$STACK_OPERATION" == "create" ]]; then
        # get cloud9 instance id from ssm parameter store
        C9_PID=$(aws ssm get-parameter \
            --name "$CLOUD9_INSTANCE_ID_PARAMETER_NAME" \
            --output text \
            --query "Parameter.Value") 

        run_ssm_command "$TARGET_USER" "$C9_PID" "cd ~/environment && git clone --single-branch --branch $GIT_BRANCH $GIT_REPO"
        run_ssm_command "$TARGET_USER" "$C9_PID" "rm -vf ~/.aws/credentials"
        run_ssm_command "$TARGET_USER" "$C9_PID" "cd ~/environment/aws-saas-factory-saas-microservices-workshop && ./setup.sh"
        run_ssm_command "$TARGET_USER" "$C9_PID" "cd ~/environment/aws-saas-factory-saas-microservices-workshop && ./deploy.sh"
        aws ec2 reboot-instances --instance-ids "$C9_PID"
    fi
elif [ "$STACK_OPERATION" == "delete" ]; then
    C9_PID=$(aws ssm get-parameter \
        --name "$CLOUD9_INSTANCE_ID_PARAMETER_NAME" \
        --output text \
        --query "Parameter.Value" 2>/dev/null) #suppress error if C9 has not been created

    if [ -z "$C9_PID" ]; then
        run_ssm_command "$TARGET_USER" "$C9_PID" "cd ~/environment/aws-saas-factory-saas-microservices-workshop && ./destroy.sh"
    fi
    
    echo "Starting cdk destroy..."
    npx cdk destroy --all --force
    echo "Done cdk destroy!"
else
    echo "Invalid stack operation!"
    exit 1
fi
