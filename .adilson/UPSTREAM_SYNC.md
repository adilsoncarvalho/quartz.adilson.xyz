# Syncing with Upstream Quartz Repository

This document explains how to sync your fork with the upstream Quartz repository.

## Initial Setup

If you haven't already added the upstream remote, run:

```bash
git remote add upstream https://github.com/jackyzha0/quartz.git
```

## Creating/Updating the v4 Branch

### First Time Setup

To create a local `v4` branch that tracks the upstream `v4` branch:

```bash
# Fetch all branches from upstream
git fetch upstream

# Create local v4 branch tracking upstream/v4
git checkout -b v4 upstream/v4
```

### Keeping Your v4 Branch Updated

To sync your local `v4` branch with the latest changes from upstream:

```bash
# Switch to v4 branch
git checkout v4

# Fetch latest changes from upstream
git fetch upstream

# Merge upstream changes
git merge upstream/v4
```

Or use a single command:

```bash
git checkout v4
git pull upstream v4
```

## Checking Remote Configuration

To verify your remotes are set up correctly:

```bash
git remote -v
```

You should see:
- `origin` pointing to your fork (`git@github.com:adilsoncarvalho/quartz.adilson.xyz.git`)
- `upstream` pointing to the original repository (`https://github.com/jackyzha0/quartz.git`)

## Fetching Latest Tags

To get the latest version tags from upstream:

```bash
git fetch upstream --tags
```
