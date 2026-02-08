# Security Policy

## GitHub Actions Security

This repository implements security best practices for GitHub Actions in a public repository:

### Workflow Trigger Security

1. **Release Workflow** (`release-on-main.yml`):
   - Triggers only on `push` events to the `main` branch
   - Only repository maintainers with write access can push to `main`
   - Has minimal required permissions (`contents: write` for creating releases)
   - Does not run on pull requests, preventing untrusted code execution

2. **Pull Request Workflows**:
   - Any CI workflows that run on pull requests use the `pull_request` trigger (not `pull_request_target`)
   - The `pull_request` trigger runs the workflow code from the PR branch but in a restricted context:
     - No access to repository secrets
     - Read-only GITHUB_TOKEN by default
     - Runs in an isolated environment
   - This prevents malicious PRs from accessing secrets or modifying the repository

### Required GitHub Repository Settings

To ensure maximum security, configure the following settings in the repository:

1. **Branch Protection for `main`**:
   - Require pull request reviews before merging
   - Require status checks to pass before merging
   - Restrict who can push to the branch (maintainers only)

2. **Actions Permissions**:
   - Go to Settings → Actions → General
   - Under "Fork pull request workflows from outside collaborators":
     - Select "Require approval for first-time contributors"
   - This ensures that workflows on PRs from new contributors require manual approval

3. **Secrets Management**:
   - Never log secrets or expose them in workflow outputs
   - Use environment-specific secrets when possible
   - Review secret access in workflow files regularly

### Reporting Security Issues

If you discover a security vulnerability in this repository or its workflows, please report it privately to the repository maintainers rather than opening a public issue.
