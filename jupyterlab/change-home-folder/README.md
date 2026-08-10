# Change JupyterLab Home Folder

This lifecycle configuration script clones a Git repository and sets it as the root directory for the JupyterLab file browser.

## Use Case

When you want users to land directly in a specific repository folder when they open JupyterLab, rather than the default `/home/sagemaker-user/` directory. Useful for:
- Ensuring new files are created inside the repo by default
- Providing a focused workspace for a specific project
- Reducing navigation overhead for users

## How It Works

1. Clones a Git repository into `/home/sagemaker-user/<folder-name>` (skips if already cloned)
2. Generates a Jupyter server config
3. Sets `c.ServerApp.root_dir` to the cloned repo path
4. Restarts the Jupyter server to apply the change

## Configuration

Edit `on-start.sh` and replace the placeholder values:

| Variable | Description | Example |
|----------|-------------|---------|
| `URL` | Git clone URL of the repository | `https://github.com/aws-samples/sagemaker-studio-lifecycle-config-examples.git` |
| `FOLDER` | Local folder name for the clone | `sagemaker-studio-lifecycle-config-examples` |

## Prerequisites

- The JupyterLab app needs internet access to clone the repository
- If the repository is private, configure Git credentials before running this script (or use a public repo)

## Notes

- The script is idempotent — if the folder already exists, it skips the clone step
- The JupyterLab file browser will show only the contents of the cloned repo
- Users can still access other directories via the terminal
