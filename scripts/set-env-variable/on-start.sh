# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

#!/bin/bash
set -eux

# OVERVIEW
# This script sets environment variable across Jupyter notebooks
# replace KEY and VALUE to your desired env. variables

# set for notebooks
mkdir -p ~/.ipython/profile_default/startup/
touch ~/.ipython/profile_default/startup/00-startup.py
echo "import sys,os,os.path" | tee -a ~/.ipython/profile_default/startup/00-startup.py >/dev/null
echo "os.environ['KEY']="\""VALUE"\""" | tee -a ~/.ipython/profile_default/startup/00-startup.py >/dev/null