# Container README

Developed on Ubuntu 24

## Starting the Container

To start the container, use the following command:

```bash
docker-compose -f docker-compose-claude-flow.yml up -d
```

**Note:** After starting the container, please wait a moment for the startup script to complete before proceeding.

## Connecting as the Claude User

To connect to the container as the claude user:

```bash
docker exec -it claude-flow-container su - claude
```

## Use claude and claude-flow

Connect the claude user:

```bash
claude
```
```bash
claude-flow init --force
```

To start an next.js dev Server run:
```bash
npm run dev -- -H 0.0.0.0
```
After that you can run http://localhost:4001 on the Host. For more Info see .yml

## Authentication

### GitHub Authentication

To authenticate with GitHub, you need to run:

```bash
gh auth login
```

Follow the prompts to complete the GitHub CLI authentication process.

### SSH Key Authentication

The container will attempt to copy SSH keys from your `.ssh` directory for Git authentication. This is useful if you prefer not to use the GitHub CLI.

The startup script will look for SSH keys in the mounted `.ssh` directory and copy them to the appropriate location within the container.

## Additional Notes

- Ensure all necessary volumes are mounted when starting the container
- The startup script handles initial configuration automatically
- For SSH authentication to work properly, mount your `.ssh` directory as a volume
