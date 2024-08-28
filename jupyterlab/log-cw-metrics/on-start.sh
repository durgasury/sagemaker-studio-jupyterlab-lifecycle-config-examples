# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

#!/bin/bash
set -eux

CONDA_HOME=/opt/conda/bin
PYTHON_SCRIPT_PATH=/var/tmp/log_metrics.py  # update it to use your path
LOG_FILE=/var/log/apps/app_container.log
sudo apt-get update -y

# Check if cron needs to be installed  ## Handle scenario where script exiting("set -eux") due to non-zero return code by adding true command.
status="$(dpkg-query -W --showformat='${db:Status-Status}' "cron" 2>&1)" || true 
if [ ! $? = 0 ] || [ ! "$status" = installed ]; then
	# Fixing invoke-rc.d: policy-rc.d denied execution of restart.
	sudo /bin/bash -c "echo '#!/bin/sh
	exit 0' > /usr/sbin/policy-rc.d"

	# Installing cron.
	echo "Installing cron..."
	sudo apt install cron
else
	echo "Package cron is already installed."
        # start/restart the service.
	sudo service cron restart
fi

# Setting container credential URI variable to /etc/environment to make it available to cron
sudo /bin/bash -c "echo 'AWS_CONTAINER_CREDENTIALS_RELATIVE_URI=$AWS_CONTAINER_CREDENTIALS_RELATIVE_URI' >> /etc/environment"
sudo /bin/bash -c "echo 'AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION' >> /etc/environment"


# Add script to crontab for root.
echo "Adding log_metrics script to crontab..."
echo "* * * * * /bin/bash -ic '$CONDA_HOME/python $PYTHON_SCRIPT_PATH >> $LOG_FILE 2>&1'" | sudo crontab -