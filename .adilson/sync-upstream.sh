#!/bin/bash

# Upstream Sync Script for Quartz
# ==================================
#
# PURPOSE:
# This script syncs the notes.adilson.xyz branch with the upstream Quartz v4 repository.
# It automates the process of rebasing your fork onto the latest upstream changes while
# intelligently handling common conflicts, particularly in package files.
#
# HOW IT WORKS:
# 1. Verifies upstream remote exists and is configured correctly
# 2. Fetches latest changes from upstream/v4
# 3. Creates or updates local v4 tracking branch
# 4. Performs rebase of notes.adilson.xyz onto upstream/v4
# 5. Enters automatic conflict resolution loop if conflicts are detected
# 6. Auto-resolves package.json and package-lock.json conflicts
# 7. Prompts for manual resolution only when non-package conflicts exist
#
# AUTOMATIC CONFLICT RESOLUTION:
# - package.json: Accepts upstream version (git checkout --theirs)
# - package-lock.json: Regenerated via npm install
# - Loop-based: Continues through multiple commits with package conflicts
# - Safety limit: Maximum 10 automatic resolution attempts
# - Semi-automatic: If package + other file conflicts exist, resolves package files
#   automatically and prompts for manual resolution of remaining conflicts
#
# KEY FEATURES:
# - No editor prompts during rebase (GIT_EDITOR=true)
# - Handles package conflicts across multiple commits automatically
# - Clear progress indicators and colored output
# - Graceful fallback to manual resolution when needed
# - Safety checks for uncommitted changes
#
# USAGE:
# ./.adilson/sync-upstream.sh
#
# AFTER SUCCESSFUL SYNC:
# git push origin notes.adilson.xyz --force-with-lease
#
# TO ABORT IF ISSUES OCCUR:
# git rebase --abort

set -e  # Exit on error (except where we handle errors explicitly)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
UPSTREAM_REMOTE="upstream"
UPSTREAM_URL="https://github.com/jackyzha0/quartz.git"
UPSTREAM_BRANCH="v4"
TARGET_BRANCH="notes.adilson.xyz"

echo -e "${BLUE}=== Quartz Upstream Sync Script ===${NC}\n"

# Step 1: Check and add upstream remote if needed
echo -e "${BLUE}Step 1: Checking upstream remote...${NC}"
if ! git remote | grep -q "^${UPSTREAM_REMOTE}$"; then
    echo -e "${YELLOW}Upstream remote not found. Adding it...${NC}"
    git remote add ${UPSTREAM_REMOTE} ${UPSTREAM_URL}
    echo -e "${GREEN}✓ Upstream remote added${NC}\n"
else
    echo -e "${GREEN}✓ Upstream remote already exists${NC}\n"
fi

# Verify remote configuration
echo -e "${BLUE}Current remotes:${NC}"
git remote -v | grep -E "(origin|upstream)"
echo ""

# Step 2: Fetch from upstream
echo -e "${BLUE}Step 2: Fetching latest changes from upstream...${NC}"
git fetch ${UPSTREAM_REMOTE}
git fetch ${UPSTREAM_REMOTE} --tags
echo -e "${GREEN}✓ Fetched upstream changes${NC}\n"

# Step 3: Check if local v4 branch exists
echo -e "${BLUE}Step 3: Managing local v4 branch...${NC}"
if git show-ref --verify --quiet refs/heads/${UPSTREAM_BRANCH}; then
    echo -e "${YELLOW}Local v4 branch exists. Updating it...${NC}"
    git checkout ${UPSTREAM_BRANCH}
    git pull ${UPSTREAM_REMOTE} ${UPSTREAM_BRANCH}
    echo -e "${GREEN}✓ Local v4 branch updated${NC}\n"
else
    echo -e "${YELLOW}Local v4 branch doesn't exist. Creating it...${NC}"
    git checkout -b ${UPSTREAM_BRANCH} ${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH}
    echo -e "${GREEN}✓ Local v4 branch created${NC}\n"
fi

# Step 4: Switch back to target branch
echo -e "${BLUE}Step 4: Switching to ${TARGET_BRANCH} branch...${NC}"
git checkout ${TARGET_BRANCH}
echo -e "${GREEN}✓ Switched to ${TARGET_BRANCH}${NC}\n"

# Step 5: Check for uncommitted changes
echo -e "${BLUE}Step 5: Checking for uncommitted changes...${NC}"
if ! git diff-index --quiet HEAD --; then
    echo -e "${RED}✗ You have uncommitted changes!${NC}"
    echo -e "${YELLOW}Please commit or stash your changes before merging.${NC}"
    echo ""
    git status --short
    exit 1
fi
echo -e "${GREEN}✓ Working directory is clean${NC}\n"

# Step 6: Attempt to rebase target branch onto v4
echo -e "${BLUE}Step 6: Rebasing ${TARGET_BRANCH} onto ${UPSTREAM_BRANCH}...${NC}"

# Set GIT_EDITOR to true to prevent editor from opening during rebase --continue
export GIT_EDITOR=true

# Try initial rebase
if git rebase ${UPSTREAM_BRANCH}; then
    echo -e "${GREEN}✓ Rebase completed successfully!${NC}\n"

    # Show summary
    echo -e "${BLUE}=== Rebase Summary ===${NC}"
    echo -e "${GREEN}Your ${TARGET_BRANCH} branch has been rebased onto the latest upstream v4.${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Review the changes: git log --oneline --graph -10"
    echo "2. Test your site locally"
    echo "3. Force push to your remote: git push origin ${TARGET_BRANCH} --force-with-lease"
    echo ""
    echo -e "${YELLOW}Note: Since this is a rebase, you'll need to force push to update your remote branch.${NC}"
    echo ""
    exit 0
fi

# Rebase failed - enter conflict resolution loop
echo -e "${RED}✗ Rebase conflicts detected!${NC}\n"
echo -e "${BLUE}=== Starting Automatic Conflict Resolution ===${NC}\n"

# Safety counter to prevent infinite loops
MAX_ITERATIONS=10
iteration=0

while [ $iteration -lt $MAX_ITERATIONS ]; do
    iteration=$((iteration + 1))
    echo -e "${BLUE}Resolution attempt ${iteration}/${MAX_ITERATIONS}${NC}"

    # Get list of conflicted files
    conflicted_files=$(git diff --name-only --diff-filter=U)

    if [ -z "$conflicted_files" ]; then
        echo -e "${GREEN}✓ No conflicts remaining${NC}\n"
        break
    fi

    echo -e "${YELLOW}Conflicting files:${NC}"
    echo "$conflicted_files"
    echo ""

    # Check if we have package.json or package-lock.json conflicts
    has_package_json=$(echo "$conflicted_files" | grep -c "^package\.json$" || true)
    has_package_lock=$(echo "$conflicted_files" | grep -c "^package-lock\.json$" || true)

    # Count total conflicts and package-related conflicts
    total_conflicts=$(echo "$conflicted_files" | wc -l | tr -d ' ')
    package_conflicts=$((has_package_json + has_package_lock))

    # Check if ALL conflicts are package-related
    if [ $package_conflicts -gt 0 ] && [ $package_conflicts -eq $total_conflicts ]; then
        echo -e "${BLUE}Auto-resolving package file conflicts...${NC}"

        # Resolve package.json if conflicted (accept upstream version)
        if [ $has_package_json -gt 0 ]; then
            echo -e "${YELLOW}→ Accepting upstream version of package.json${NC}"
            git checkout --theirs package.json
            git add package.json
        fi

        # Resolve package-lock.json if conflicted (regenerate it)
        if [ $has_package_lock -gt 0 ]; then
            echo -e "${YELLOW}→ Regenerating package-lock.json${NC}"
            rm -f package-lock.json
        fi

        # Regenerate package-lock.json based on the resolved package.json
        echo -e "${YELLOW}→ Running npm install to regenerate package-lock.json...${NC}"
        if npm install; then
            echo -e "${GREEN}✓ Successfully regenerated package-lock.json${NC}"
            git add package-lock.json

            # Try to continue the rebase
            echo -e "${BLUE}→ Continuing rebase...${NC}\n"
            if git rebase --continue; then
                echo -e "${GREEN}✓ Rebase completed successfully!${NC}\n"

                # Show summary
                echo -e "${BLUE}=== Rebase Summary ===${NC}"
                echo -e "${GREEN}Your ${TARGET_BRANCH} branch has been rebased onto the latest upstream v4.${NC}"
                echo ""
                echo -e "${BLUE}Next steps:${NC}"
                echo "1. Review the changes: git log --oneline --graph"
                echo "2. Test your site locally"
                echo "3. Force push to your remote: git push origin ${TARGET_BRANCH} --force-with-lease"
                echo ""
                echo -e "${YELLOW}Note: Since this is a rebase, you'll need to force push to update your remote branch.${NC}"
                echo ""
                exit 0
            else
                # Rebase --continue failed, but there might be more conflicts
                # Loop will continue to next iteration
                echo -e "${YELLOW}More conflicts detected, continuing resolution...${NC}\n"
                continue
            fi
        else
            echo -e "${RED}✗ npm install failed${NC}"
            echo -e "${YELLOW}Please resolve npm install issues manually${NC}"
            echo ""
            echo -e "${BLUE}To abort the rebase:${NC}"
            echo "   git rebase --abort"
            echo ""
            exit 1
        fi
    else
        # We have non-package conflicts that require manual intervention
        echo -e "${YELLOW}⚠ Found conflicts that cannot be auto-resolved${NC}\n"

        if [ $package_conflicts -gt 0 ]; then
            echo -e "${YELLOW}Package-related conflicts detected, but there are other conflicts too.${NC}"
            echo -e "${YELLOW}Resolving package files first...${NC}\n"

            # Resolve package files automatically
            if [ $has_package_json -gt 0 ]; then
                echo -e "${YELLOW}→ Auto-resolving package.json (accepting upstream version)${NC}"
                git checkout --theirs package.json
                git add package.json
            fi

            if [ $has_package_lock -gt 0 ]; then
                echo -e "${YELLOW}→ Auto-resolving package-lock.json (regenerating)${NC}"
                rm -f package-lock.json
            fi

            # Regenerate package-lock.json if needed
            if [ $has_package_json -gt 0 ] || [ $has_package_lock -gt 0 ]; then
                echo -e "${YELLOW}→ Running npm install...${NC}"
                if npm install; then
                    echo -e "${GREEN}✓ Package files resolved${NC}"
                    git add package-lock.json
                else
                    echo -e "${RED}✗ npm install failed${NC}"
                fi
            fi
            echo ""
        fi

        # Show remaining conflicts
        remaining_conflicts=$(git diff --name-only --diff-filter=U)
        echo -e "${BLUE}Remaining conflicts requiring manual resolution:${NC}"
        echo "$remaining_conflicts"
        echo ""

        echo -e "${BLUE}To resolve remaining conflicts:${NC}"
        echo "1. Edit the conflicting files shown above"
        echo "2. Look for conflict markers: <<<<<<< HEAD, =======, >>>>>>>"
        echo "3. Resolve each conflict and save the files"
        echo "4. Stage resolved files: git add <file>"
        echo "5. Continue the rebase: GIT_EDITOR=true git rebase --continue"
        echo ""
        echo -e "${BLUE}To abort the rebase:${NC}"
        echo "   git rebase --abort"
        echo ""
        echo -e "${YELLOW}Note: Package files have been auto-resolved. Only non-package conflicts remain.${NC}"
        echo ""
        exit 1
    fi
done

# If we've exhausted the iteration limit
if [ $iteration -eq $MAX_ITERATIONS ]; then
    echo -e "${RED}✗ Maximum conflict resolution attempts reached${NC}"
    echo -e "${YELLOW}The rebase process has encountered repeated conflicts.${NC}"
    echo ""
    echo -e "${BLUE}To abort the rebase:${NC}"
    echo "   git rebase --abort"
    echo ""
    echo -e "${BLUE}To continue manually:${NC}"
    echo "1. Resolve remaining conflicts"
    echo "2. Stage resolved files: git add <file>"
    echo "3. Continue: GIT_EDITOR=true git rebase --continue"
    echo ""
    exit 1
fi
