# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

#!/bin/bash
set -eux

# OVERVIEW
# This script removes all kernels other than Python
 
# customize kernels
echo "Removing Kernels other than Python"
jupyter kernelspec remove glue_pyspark -y
jupyter kernelspec remove glue_spark -y
jupyter kernelspec remove pysparkkernel -y
jupyter kernelspec remove sparkkernel -y