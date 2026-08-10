# Git Clone Repository with Per-User Branches

This lifecycle configuration script automatically clones a shared Git repository for each user in a SageMaker Studio JupyterLab space, checks out a branch named after the user, and sets up periodic auto-commit/push.

## Use Case

Teams where:
- A SageMaker domain is created per contract (IDC mode)
- Users can't see each other's files on EBS
- All users need to push code to a shared GitHub repo under their own branch
- Admins need visibility into everyone's code (e.g., if someone leaves the team)

## How It Works

1. **Retrieves credentials** from AWS Secrets Manager using a per-user secret (`git-creds/<username>`)
2. **Clones the repository** (or pulls latest if already cloned) into `/home/sagemaker-user/<repo-name>`
3. **Creates/checks out a branch** named after the user's SageMaker profile name
4. **Configures auto-commit and push** via cron (default: every 4 hours)
5. **Sets JupyterLab's file browser root** to the repo folder so new files are created inside the repo

## Prerequisites

### 1. Environment Variable

Set the following environment variable on the Space or Domain:

| Variable | Description | Example |
|----------|-------------|---------|
| `GIT_REPO_URL` | HTTPS URL of the Git repository | `https://github.com/org/repo.git` |

### 2. Secrets Manager Secret

For each user, create a secret in AWS Secrets Manager:

- **Secret name**: `git-creds/<sagemaker-user-profile-name>`
- **Secret value** (JSON):
  ```json
  {
    "username": "github-username",
    "pat": "ghp_xxxxxxxxxxxxxxxxxxxx"
  }
  ```

The `<sagemaker-user-profile-name>` must match exactly the SageMaker User Profile name assigned to the user in IAM Identity Center.

### 3. IAM Permissions

The Space or Domain execution role needs:

```json
{
  "Effect": "Allow",
  "Action": "secretsmanager:GetSecretValue",
  "Resource": "arn:aws:secretsmanager:<region>:<account-id>:secret:git-creds/*"
}
```

### 4. Network Connectivity

The JupyterLab app needs internet access to:
- Reach AWS Secrets Manager API
- Clone from and push to the Git remote (e.g., github.com)

## Configuration

Edit the `on-start.sh` script to adjust:

| Variable | Default | Description |
|----------|---------|-------------|
| `AUTO_PUSH_INTERVAL_HOURS` | `4` | How often to auto-commit and push (in hours) |

## Auto-Push Behavior

The auto-push cron job:
1. Checks if there are uncommitted changes (new, modified, or deleted files)
2. Stages all changes and commits with message: `auto-commit: <ISO-8601-timestamp>`
3. Pushes to the user's branch on the remote
4. If push fails due to conflicts:
   - Attempts `pull --rebase` then retries push
   - If rebase fails, aborts and tries merge strategy
   - If all else fails, logs a warning (changes remain committed locally, no data loss)

Logs are written to `/var/log/apps/app_container.log` (visible in CloudWatch Logs).

## Branch Strategy

- Each user gets a branch named after their SageMaker User Profile name
- On first run: creates the branch and pushes it to the remote
- On subsequent runs: checks out the existing branch and pulls latest

This gives admins full visibility via the repo — each user's work is on a named branch reviewable through normal Git workflows (PRs, code review, etc.).

## Troubleshooting

| Issue | Cause | Resolution |
|-------|-------|------------|
| Script fails at secret retrieval | Secret doesn't exist or wrong name | Verify secret is named `git-creds/<exact-profile-name>` |
| Clone fails | Bad PAT or repo URL | Check PAT permissions (needs `repo` scope) and URL |
| Auto-push logs "failed" | Network issue or token expired | Check CloudWatch logs, regenerate PAT if expired |
| JupyterLab shows wrong directory | Config not applied | Verify `restart-jupyter-server` ran successfully |
