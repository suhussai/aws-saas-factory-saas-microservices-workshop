import * as ssm from "aws-cdk-lib/aws-ssm";
import { DockerImageAsset } from "aws-cdk-lib/aws-ecr-assets";
import { Construct } from "constructs";
var path = require("path");

export class SharedStack extends Construct {
  public readonly sharedImageSSMParameterName: string;
  constructor(scope: Construct, id: string) {
    super(scope, id);

    const sharedImageAsset = new DockerImageAsset(
      this,
      "ProductAppContainerImage",
      {
        directory: path.join(__dirname, "../app"),
      }
    );

    const sharedImageSSMParameterName = new ssm.StringParameter(
      this,
      "sharedImage",
      {
        stringValue: sharedImageAsset.imageUri,
      }
    );
    this.sharedImageSSMParameterName =
      sharedImageSSMParameterName.parameterName;
  }
}