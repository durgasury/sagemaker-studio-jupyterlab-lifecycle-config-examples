# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

#!/bin/bash
set -eux

# OVERVIEW
# This script clones a Git repository (configured via environment variable) into the user's home directory,
# creates or checks out a branch named after the user's profile, configures auto-commit/push on a schedule,
# and sets the JupyterLab file browser root to the cloned repo folder.
#
# Prerequisites:
#   1. Environment variables set on the Space or Domain:
#      - GIT_REPO_URL: HTTPS URL of the Git repository (e.g., https://github.com/org/repo.git)
#   2. A secret in AWS Secrets Manager named "git-creds/<username>" containing a JSON object:
#      { "username": "<git-username>", "pat": "<personal-access-token>" }
#      where <username> matches the SageMaker User Profile name (SAGEMAKER_USER_PROFILE_NAME).
#   3. The Space/Domain execution role must have permissions for:
#      - secretsmanager:GetSecretValue on the relevant secret ARN
#   4. Internet connectivity from the JupyterLab app (to clone/push to the remote repo)

# ─── User Configuration ─────────────────────────────────────────────────────────

AUTO_PUSH_INTERVAL_HOURS=4  # How often (in hours) to auto-commit and push changes

# ─── System Variables ────────────────────────────────────────────────────────────

HOME_DIR=/home/sagemaker-user
LOG_FILE=/var/log/apps/app_container.log
CONDA_HOME=/opt/conda/bin
USERNAME="${SAGEMAKER_USER_PROFILE_NAME}"
SECRET_NAME="git-creds/${USERNAME}"
REPO_URL="${GIT_REPO_URL}"

# Extract repo folder name from URL (e.g., https://github.com/org/repo.git -> repo)
REPO_FOLDER=$(basename "${REPO_URL}" .git)
REPO_PATH="${HOME_DIR}/${REPO_FOLDER}"
AUTO_PUSH_SCRIPT="/var/tmp/git-auto-push.sh"

# ─── Retrieve Git Credentials from Secrets Manager ───────────────────────────────

echo "Retrieving Git credentials from Secrets Manager for: ${SECRET_NAME}"

# Get the AWS region from instance metadata or default
AWS_REGION=$(aws configure get region 2>/dev/null || echo "us-east-1")

SECRET_VALUE=$(aws secretsmanager get-secret-value \
    --secret-id "${SECRET_NAME}" \
    --region "${AWS_REGION}" \
    --query 'SecretString' \
    --output text)

GIT_USERNAME=$(echo "${SECRET_VALUE}" | python3 -c "import sys, json; print(json.load(sys.stdin)['username'])")
GIT_PAT=$(echo "${SECRET_VALUE}" | python3 -c "import sys, json; print(json.load(sys.stdin)['pat'])")

# ─── Configure Git Credentials ──────────────────────────────────────────────────

# Configure git credential helper to use the retrieved PAT
git config --global credential.helper 'store'

# Build authenticated URL for credential store
REPO_HOST=$(echo "${REPO_URL}" | python3 -c "import sys; from urllib.parse import urlparse; print(urlparse(sys.stdin.read().strip()).hostname)")
echo "https://${GIT_USERNAME}:${GIT_PAT}@${REPO_HOST}" > "${HOME_DIR}/.git-credentials"
chmod 600 "${HOME_DIR}/.git-credentials"

# Configure git user identity
git config --global user.name "${USERNAME}"
git config --global user.email "${USERNAME}@users.noreply.github.com"

# ─── Clone or Update Repository ─────────────────────────────────────────────────

BRANCH_NAME="${USERNAME}"

if [ ! -d "${REPO_PATH}/.git" ]; then
    echo "Cloning repository: ${REPO_URL}"
    git clone "${REPO_URL}" "${REPO_PATH}"
    cd "${REPO_PATH}"

    # Check if the user's branch exists on remote
    if git ls-remote --exit-code --heads origin "${BRANCH_NAME}" > /dev/null 2>&1; then
        echo "Branch '${BRANCH_NAME}' exists on remote. Checking out..."
        git checkout "${BRANCH_NAME}"
    else
        echo "Branch '${BRANCH_NAME}' does not exist. Creating..."
        git checkout -b "${BRANCH_NAME}"
        git push -u origin "${BRANCH_NAME}"
    fi
else
    echo "Repository already exists at ${REPO_PATH}. Pulling latest changes..."
    cd "${REPO_PATH}"

    # Ensure we're on the correct branch
    CURRENT_BRANCH=$(git branch --show-current)
    if [ "${CURRENT_BRANCH}" != "${BRANCH_NAME}" ]; then
        if git ls-remote --exit-code --heads origin "${BRANCH_NAME}" > /dev/null 2>&1; then
            git checkout "${BRANCH_NAME}"
        else
            git checkout -b "${BRANCH_NAME}"
            git push -u origin "${BRANCH_NAME}"
        fi
    fi

    # Pull latest changes safely
    git pull --rebase origin "${BRANCH_NAME}" || {
        echo "Rebase failed during pull. Aborting rebase and retrying with merge..."
        git rebase --abort 2>/dev/null || true
        git pull --no-rebase origin "${BRANCH_NAME}" || {
            echo "WARNING: Pull failed. Continuing with local state." | tee -a "${LOG_FILE}"
        }
    }
fi

# ─── Set Up Auto-Commit and Push Script ─────────────────────────────────────────

cat > "${AUTO_PUSH_SCRIPT}" << 'SCRIPT'
#!/bin/bash
set -e

REPO_PATH="__REPO_PATH__"
BRANCH_NAME="__BRANCH_NAME__"
LOG_FILE="__LOG_FILE__"

cd "${REPO_PATH}" || exit 1

# Check if there are any changes to commit
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    echo "$(date -Iseconds) - No changes to commit." >> "${LOG_FILE}"
    exit 0
fi

echo "$(date -Iseconds) - Auto-committing changes..." >> "${LOG_FILE}"

# Stage all changes (new, modified, deleted)
git add -A

# Commit with timestamp
git commit -m "auto-commit: $(date -Iseconds)" || {
    echo "$(date -Iseconds) - Nothing to commit after staging." >> "${LOG_FILE}"
    exit 0
}

# Push with conflict handling
echo "$(date -Iseconds) - Pushing to origin/${BRANCH_NAME}..." >> "${LOG_FILE}"
git push origin "${BRANCH_NAME}" 2>> "${LOG_FILE}" || {
    echo "$(date -Iseconds) - Push failed. Attempting pull --rebase then push..." >> "${LOG_FILE}"
    git pull --rebase origin "${BRANCH_NAME}" 2>> "${LOG_FILE}" && \
    git push origin "${BRANCH_NAME}" 2>> "${LOG_FILE}" || {
        echo "$(date -Iseconds) - Rebase failed. Aborting and trying merge strategy..." >> "${LOG_FILE}"
        git rebase --abort 2>/dev/null || true
        git pull --no-rebase origin "${BRANCH_NAME}" 2>> "${LOG_FILE}" && \
        git push origin "${BRANCH_NAME}" 2>> "${LOG_FILE}" || {
            echo "$(date -Iseconds) - WARNING: Auto-push failed. Changes are committed locally. Manual push required." >> "${LOG_FILE}"
            exit 1
        }
    }
}

echo "$(date -Iseconds) - Auto-push completed successfully." >> "${LOG_FILE}"
SCRIPT

# Replace placeholders with actual values
sed -i "s|__REPO_PATH__|${REPO_PATH}|g" "${AUTO_PUSH_SCRIPT}"
sed -i "s|__BRANCH_NAME__|${BRANCH_NAME}|g" "${AUTO_PUSH_SCRIPT}"
sed -i "s|__LOG_FILE__|${LOG_FILE}|g" "${AUTO_PUSH_SCRIPT}"
chmod +x "${AUTO_PUSH_SCRIPT}"

# ─── Install and Configure Cron ──────────────────────────────────────────────────

# Check if cron needs to be installed
status="$(dpkg-query -W --showformat='${db:Status-Status}' "cron" 2>&1)" || true
if [ ! $? = 0 ] || [ ! "$status" = installed ]; then
    sudo /bin/bash -c "echo '#!/bin/sh
exit 0' > /usr/sbin/policy-rc.d"
    echo "Installing cron..."
    sudo apt install -y cron
else
    echo "Cron is already installed."
    sudo service cron restart
fi

# Setting container credential URI variable to /etc/environment for cron access
sudo /bin/bash -c "echo 'AWS_CONTAINER_CREDENTIALS_RELATIVE_URI=${AWS_CONTAINER_CREDENTIALS_RELATIVE_URI}' >> /etc/environment"

# Schedule auto-push (every N hours)
echo "Setting up auto-push cron job (every ${AUTO_PUSH_INTERVAL_HOURS} hours)..."
echo "0 */${AUTO_PUSH_INTERVAL_HOURS} * * * /bin/bash ${AUTO_PUSH_SCRIPT}" | sudo crontab -

# ─── Configure JupyterLab Root Directory ─────────────────────────────────────────

echo "Setting JupyterLab root directory to: ${REPO_PATH}"
jupyter server --generate-config -y
echo "c.ServerApp.root_dir = '${REPO_PATH}/'" >> /home/sagemaker-user/.jupyter/jupyter_server_config.py

restart-jupyter-server
