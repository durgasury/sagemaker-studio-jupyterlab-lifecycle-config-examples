# SageMaker Studio Lifecycle Configuration examples

## Overview
A collection of sample scripts customizing SageMaker Studio applications using lifecycle configurations.

Lifecycle Configurations (LCCs) provide a mechanism to customize SageMaker Studio applications via shell scripts that are executed at application bootstrap. For further information on how to use lifecycle configurations with SageMaker Studio applications, please refer to the AWS documentation:

- [Using Lifecycle Configurations with JupyterLab](https://docs.aws.amazon.com/sagemaker/latest/dg/jl-lcc.html)
- [Using Lifecycle Configurations with Code Editor](https://docs.aws.amazon.com/sagemaker/latest/dg/code-editor-use-lifecycle-configurations.html)

> **Warning**
> The sample scripts in this repository are designed to work with SageMaker Studio JupyterLab and Code Editor applications. If you are using SageMaker Studio Classic, please refer to https://github.com/aws-samples/sagemaker-studio-lifecycle-config-examples

## Sample Scripts

### [SageMaker JupyterLab](https://docs.aws.amazon.com/sagemaker/latest/dg/studio-updated-jl.html)
- [auto-stop-idle](jupyterlab/auto-stop-idle/) - Automatically shuts down JupyterLab applications that have been idle for a configurable time.
- [change-home-folder](jupyterlab/change-home-folder) - Clone a git repo and set it as the user's root folder.
- [remove-kernels](jupyterlab/remove-kernels) - Remove all Spark/pySpark kernels from Jupyterlab launcher.
- [upgrade-cli](jupyterlab/upgrade-cli) - Upgrades AWS CLI to get user profile name from a Jupyterlab space.
- [set-env-variable](jupyterlab/set-env-variable) - Sets common environment variables used by terminal and kernel sessions.
- [push-metrics](jupyterlab/push-metrics) - Push CPU, GPU, mem and disk metrics to Cloudwatch on a regular interval.

### [SageMaker Code Editor](https://docs.aws.amazon.com/sagemaker/latest/dg/code-editor.html)
- [auto-stop-idle](code-editor/auto-stop-idle/) - Automatically shuts down Code Editor applications that have been idle for a configurable time.

### Common scripts
These scripts will work with both SageMaker JupyterLab and SageMaker Code Editor apps. Note that if you want the script to be available across both apps, you will need to set them as an LCC script for both apps.
- [ebs-s3-backup-restore](common-scripts/ebs-s3-backup-restore) - This script backs up content in a user space's EBS volume (user's home directory under `/home/sagemaker-user`) to an S3 bucket that's specified on the script, optionally on a schedule. If the user profile is tagged with a `SM_EBS_RESTORE_TIMESTAMP` tag, then the script will restore the backup files into the user's home directory, in addition to backups.

## Developing LLCs for SageMaker Studio applications
For best practices, please check [DEVELOPMENT](DEVELOPMENT.md).

## License
This project is licensed under the [MIT-0 License](LICENSE).

## Authors
[Giuseppe A. Porcelli](https://www.linkedin.com/in/giuporcelli/) - Principal, ML Specialist Solutions Architect - Amazon SageMaker
<br />Spencer Ng - Software Development Engineer - Amazon SageMaker
<br />Durga Sury - Senior ML Specialist Solutions Architect - Amazon SageMaker