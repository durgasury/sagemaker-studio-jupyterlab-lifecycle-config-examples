# SageMaker Studio JupyterLab instance metrics
The `on-start.sh` script, designed to run as a [SageMaker Studio lifecycle configuration](https://docs.aws.amazon.com/sagemaker/latest/dg/jl-lcc.html), periodically pushes CPU, memory and GPU utilization (for GPU instances) metrics to Cloudwatch under the `/aws/sagemaker/studio` namespace. The dimensions include Domain ID, user profile name, space name and instance type. 

The background cron job runs every 5 minutes.

## Installation for all user profiles in a SageMaker Studio domain

From a terminal appropriately configured with AWS CLI, run the following commands:
  

    REGION=<aws_region>
    DOMAIN_ID=<domain_id>
    ACCOUNT_ID=<aws_account_id>
    LCC_NAME=log-cw-metrics
    LCC_CONTENT=`openssl base64 -A -in on-start.sh`

    aws sagemaker create-studio-lifecycle-config \
        --studio-lifecycle-config-name $LCC_NAME \
        --studio-lifecycle-config-content $LCC_CONTENT \
        --studio-lifecycle-config-app-type JupyterLab \
        --query 'StudioLifecycleConfigArn'

    aws sagemaker update-domain \
        --region $REGION \
        --domain-id $DOMAIN_ID \
        --default-user-settings \
        "{
          \"JupyterLabAppSettings\": {
            \"DefaultResourceSpec\": {
              \"LifecycleConfigArn\": \"arn:aws:sagemaker:$REGION:$ACCOUNT_ID:studio-lifecycle-config/$LCC_NAME\",
              \"InstanceType\": \"ml.t3.medium\"
            },
            \"LifecycleConfigArns\": [
              \"arn:aws:sagemaker:$REGION:$ACCOUNT_ID:studio-lifecycle-config/$LCC_NAME\"
            ]
          }
        }"

Make sure to replace `<aws_region>`, `<domain_id>`, and `<aws_account_id>` in the previous commands with the AWS region, the Studio domain ID, and AWS Account ID you are using respectively. Note that the above command sets the script as the default for the domain. 


**Note**
1. The cron job runs every `5` minutes. You can edit this by updating the cron schedule in line 35.
2. If running in internet-free mode (VPC-only), copy the `log_metrics.py` script to an S3 bucket and replace the `curl` command with an `aws s3 cp` command. 