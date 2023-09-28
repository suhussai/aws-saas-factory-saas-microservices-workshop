import * as cr from "aws-cdk-lib/custom-resources";
import * as iam from "aws-cdk-lib/aws-iam";
import * as ssm from "aws-cdk-lib/aws-ssm";
import * as logs from "aws-cdk-lib/aws-logs";
import * as aws_lambda from "aws-cdk-lib/aws-lambda";
import * as cdk from "aws-cdk-lib";
import { Construct } from "constructs";

var path = require("path");
export class Cloud9Resources extends Construct {
  constructor(
    scope: Construct,
    id: string,
    props: {
      createCloud9Instance: boolean;
      workshopSSMPrefix: string;
      cloud9MemberArn?: string;
      cloud9ConnectionType: string;
      cloud9InstanceType: string;
      cloud9ImageId: string;
    }
  ) {
    super(scope, id);

    const createCloud9Instance = props.createCloud9Instance;
    const workshopSSMPrefix = props.workshopSSMPrefix;
    const cloud9ConnectionType = props.cloud9ConnectionType;
    const cloud9InstanceType = props.cloud9InstanceType;
    const cloud9ImageId = props.cloud9ImageId;

    if (createCloud9Instance) {
      const cloud9TagKey = "WORKSHOP";
      const cloud9TagValue = "saas-microservices";

      if (!props.cloud9MemberArn) {
        console.error(
          "Missing parameter: 'cloud9MemberArn'. Cloud9 instance will be created without member."
        );
      }

      const cloud9Role = new iam.Role(this, "Cloud9Role", {
        assumedBy: new iam.ServicePrincipal("ec2.amazonaws.com"),
        managedPolicies: [
          iam.ManagedPolicy.fromAwsManagedPolicyName("AdministratorAccess"),
        ],
      });

      const cloud9InstanceProfile = new iam.InstanceProfile(
        this,
        "Cloud9InstanceProfile",
        {
          role: cloud9Role,
        }
      );

      const cloud9InstanceIdSSMParameterName = `${workshopSSMPrefix}/cloud9InstanceId`;
      const cloud9InstanceEnvIdSSMParameterName = `${workshopSSMPrefix}/cloud9EnvironmentId`;
      const cloud9InstanceProfileName = `${workshopSSMPrefix}/cloud9InstanceProfileName`;

      new ssm.StringParameter(this, "cloud9InstanceProfileNameSSMParameter", {
        parameterName: cloud9InstanceProfileName,
        stringValue: cloud9InstanceProfile.instanceProfileName,
      });

      const onEventLambdaCloud9InstanceUpdater = new aws_lambda.Function(
        this,
        "onEventLambdaCloud9InstanceUpdater",
        {
          runtime: aws_lambda.Runtime.PYTHON_3_11,
          handler: "index.on_event",
          code: aws_lambda.Code.fromAsset(
            path.join(__dirname, "lambda-custom-resource/")
          ),
          timeout: cdk.Duration.minutes(14), // 15 min is the max
          initialPolicy: [
            new iam.PolicyStatement({
              actions: [
                "ec2:ReplaceIamInstanceProfileAssociation",
                "ec2:DescribeInstances",
                "ec2:RebootInstances",
                "ec2:AssociateIamInstanceProfile",
                "ec2:ReplaceIamInstanceProfileAssociation",
              ],
              resources: [
                cdk.Stack.of(this).formatArn({
                  service: "ec2",
                  resource: "instance",
                  resourceName: "*",
                }),
              ],
            }),
            new iam.PolicyStatement({
              actions: [
                "ec2:DescribeInstances",
                "ssm:PutParameter",
                "ssm:DeleteParameter",
                "iam:GetRole",
                "iam:GetInstanceProfile",
                "ec2:DescribeIamInstanceProfileAssociations",
              ],
              resources: ["*"],
            }),
            new iam.PolicyStatement({
              actions: [
                "iam:CreateRole",
                "iam:AttachRolePolicy",
                "iam:CreateInstanceProfile",
                "iam:AddRoleToInstanceProfile",
                "iam:PassRole",
                "iam:ListAttachedRolePolicies",
              ],
              resources: [
                "arn:aws:iam::aws:policy/AWSCloud9SSMInstanceProfile",
                "arn:aws:iam::*:role/service-role/AWSCloud9SSMAccessRole",
                "arn:aws:iam::*:instance-profile/cloud9/AWSCloud9SSMInstanceProfile",
              ],
            }),
            new iam.PolicyStatement({
              actions: ["iam:PassRole"],
              resources: [
                cloud9Role.roleArn,
                cloud9InstanceProfile.instanceProfileArn,
              ],
            }),
          ],
        }
      );

      onEventLambdaCloud9InstanceUpdater.role?.addManagedPolicy(
        iam.ManagedPolicy.fromAwsManagedPolicyName("AWSCloud9Administrator")
      );

      const customResourceProvider = new cr.Provider(
        this,
        "cloud9InstanceUpdater",
        {
          onEventHandler: onEventLambdaCloud9InstanceUpdater,
          logRetention: logs.RetentionDays.ONE_DAY,
        }
      );

      new cdk.CustomResource(this, "Cloud9InstanceUpdaterCustomResource", {
        serviceToken: customResourceProvider.serviceToken,
        resourceType: "Custom::cloud9InstanceUpdater",
        properties: {
          name: `workshop-instance-${this.node.addr}`,
          instanceProfileName: cloud9InstanceProfile.instanceProfileName,
          instanceTagKey: cloud9TagKey,
          instanceTagValue: cloud9TagValue,
          ssmInstanceIdParameterName: cloud9InstanceIdSSMParameterName,
          ssmEnvIdParameterName: cloud9InstanceEnvIdSSMParameterName,
          connectionType: cloud9ConnectionType,
          instanceType: cloud9InstanceType,
          imageId: cloud9ImageId,
          ...(props.cloud9MemberArn && {
            memberArn: props.cloud9MemberArn,
          }),
        },
      });
    }
  }
}
