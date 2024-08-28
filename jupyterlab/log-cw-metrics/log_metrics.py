# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import json
import boto3
import requests
import datetime
import subprocess
import logging as log


def ReadFromFile(filename):
    """
    Function to read data from json files
    """
    try:
        with open(filename, "r") as meta_file:
            data = json.load(meta_file)
        return data
    except FileNotFoundError:
        log.error(f"File {filename} not found")
        raise FileNotFoundError(f"File {filename} not found")
    except Exception as error:
        UnhandledError(error)


def query_JS(host, port, url):
    response = requests.get(f'http://{host}:{port}/{url}')
    if response.status_code == 200:
        return json.loads(response.text)
    else:
        return response.status_code


def is_gpu_instance(instance_type):
    gpu_instance_types = [
        'ml.p3', 'ml.p4', 'ml.p5',  # NVIDIA Tesla GPUs
        'ml.g4', 'ml.g5', 'ml.g6',  # NVIDIA GRID GPUs
    ]
    return any(instance_type.startswith(gpu_type) for gpu_type in gpu_instance_types)


def get_gpu_utilization():
    try:
        # Run the `nvidia-smi` command
        result = subprocess.run(['nvidia-smi', '--query-gpu=utilization.gpu', '--format=csv,noheader,nounits'], 
                                stdout=subprocess.PIPE, 
                                stderr=subprocess.PIPE, 
                                text=True)
        # Split the output into lines and convert the first line to integer
        utilization = result.stdout.strip().split('\n')[0]
        return int(utilization)
    except Exception as e:
        print(f"An error occurred: {e}")
        return 0


if __name__ == "__main__":
    log.basicConfig(
        format='%(asctime)s %(levelname)s [%(filename)s:%(lineno)d]: %(message)s',
        datefmt='%m/%d/%Y %H:%M:%S',
        filename='/var/log/apps/app_container.log',
        level=log.INFO
    )
    host = "0.0.0.0"
    port = 8888
    url = "jupyterlab/default/aws/sagemaker/api/instance/metrics"
    failed = False
    resource_metadata = "/opt/ml/metadata/resource-metadata.json"
    name_space = "/aws/sagemaker/studio"
    resource_meta = ReadFromFile(resource_metadata)
    domain_id = resource_meta["DomainId"]
    space_name = resource_meta.get("SpaceName", "NoSpaceName")
    sm_client = boto3.client('sagemaker')
    response = sm_client.describe_space(
        DomainId=domain_id,
        SpaceName=space_name
    )
    user_profile_name = response.get('OwnershipSettings', {}).get("OwnerUserProfileName", "NoOwner")
    instance_type = sm_client.describe_app(
        DomainId=domain_id,
        SpaceName=space_name,
        AppName="default",
        AppType=response["SpaceSettings"]["AppType"]
    )["ResourceSpec"]["InstanceType"]
    dimensions = [
        {
            "Name": "DomainId",
            "Value": domain_id
        },
        {
            "Name": "UserProfileName",
            "Value": user_profile_name
        },
        {
            "Name": "SpaceName",
            "Value": space_name
        },
        {
            "Name": "InstanceType",
            "Value": instance_type
        }
    ]
    try:
        cw_client = boto3.client("cloudwatch")
        metrics = query_JS(host, port, url)

        if is_gpu_instance(instance_type):
            cw_client.put_metric_data(
                Namespace=name_space,
                MetricData=[
                    {
                        "MetricName": "CPUUtilization",
                        "Dimensions": dimensions,
                        "Value": metrics["metrics"]["cpu"]["cpu_percentage"],
                        "Unit": "Percent"
                    },
                    {
                        "MetricName": "MemoryUtilization",
                        "Dimensions": dimensions,
                        "Value": metrics["metrics"]["memory"]["memory_percentage"],
                        "Unit": "Percent"
                    },
                    {
                        "MetricName": "GPUUtilization",
                        "Dimensions": dimensions,
                        "Value": get_gpu_utilization(),
                        "Unit": "Percent"
                    }
                ]
            )
        else:
                cw_client.put_metric_data(
                Namespace=name_space,
                MetricData=[
                    {
                        "MetricName": "CPUUtilization",
                        "Dimensions": dimensions,
                        "Value": metrics["metrics"]["cpu"]["cpu_percentage"],
                        "Unit": "Percent"
                    },
                    {
                        "MetricName": "MemoryUtilization",
                        "Dimensions": dimensions,
                        "Value": metrics["metrics"]["memory"]["memory_percentage"],
                        "Unit": "Percent"
                    },
                ]
            )
        log.info(f"Published instance and kernel metrics at {datetime.datetime.now()}")
        print(f"Published instance and kernel metrics at {datetime.datetime.now()}")
    except Exception as e:
        log.error(f"Error publishing metrics to Cloudwatch: {e}")