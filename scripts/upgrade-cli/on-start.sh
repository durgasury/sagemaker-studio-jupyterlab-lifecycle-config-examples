# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

#!/bin/bash
set -eux

# OVERVIEW
# This script upgrades the AWS CLI, to obtain the user profile name from within a JupyterLab space

# add --proxy before apt-get if using a proxy for internet access
sudo su <<EOF
cd
apt-get update && apt-get install -yy less
apt-get remove awscli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -o awscliv2.zip
./aws/install
export PATH=/usr/local/bin/aws:$PATH
EOF

# get user profile name
sudo apt-get install -y jq
export SPACE_NAME=$(cat /opt/ml/metadata/resource-metadata.json | jq -r '.SpaceName')
export DOMAIN_ID=$(cat /opt/ml/metadata/resource-metadata.json | jq -r '.DomainId')
export USER_PROFILE_NAME=$(aws sagemaker describe-space --domain-id=$DOMAIN_ID --space-name=$SPACE_NAME | jq -r '.OwnershipSettings.OwnerUserProfileName')