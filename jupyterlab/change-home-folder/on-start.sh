# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

#!/bin/bash
set -eux

# OVERVIEW
# This script clones a specific repository and updates the JupyterLab file explorer to use the cloned repo as root folder
 
# URL=https://github.com/aws-samples/sagemaker-studio-lifecycle-config-examples.git
# FOLDER=sagemaker-studio-lifecycle-config-examples
URL="<git-url>"
FOLDER="<folder-name>"
 
if [ ! -d "$FOLDER" ] ; then
    git clone "$URL" "$FOLDER"
fi
 
jupyter server --generate-config -y
echo "c.ServerApp.root_dir = '/home/sagemaker-user/$FOLDER/'" >> /home/sagemaker-user/.jupyter/jupyter_server_config.py
 
restart-jupyter-server