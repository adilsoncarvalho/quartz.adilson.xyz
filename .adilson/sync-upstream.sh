#!/bin/bash

# Upstream Sync Script for Quartz
# This script syncs the notes.adilson.xyz branch with upstream Quartz v4

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
else
    # Rebase failed due to conflicts
    echo -e "${RED}✗ Rebase conflicts detected!${NC}\n"

    echo -e "${BLUE}=== Conflict Resolution Required ===${NC}"
    echo -e "${YELLOW}The rebase could not complete automatically due to conflicts.${NC}"
    echo ""
    echo -e "${BLUE}Conflicting files:${NC}"
    git status --short | grep "^UU\|^AA\|^DD\|^AU\|^UA"
    echo ""

    # Check if package-lock.json has conflicts
    if git status --short | grep -q "^UU package-lock.json"; then
        echo -e "${BLUE}Step 7: Auto-resolving package-lock.json conflicts...${NC}"
        echo -e "${YELLOW}Removing conflicted package-lock.json and regenerating...${NC}"

        # Remove the conflicted file
        rm package-lock.json

        # Regenerate package-lock.json by running npm install
        echo -e "${YELLOW}Running npm install to regenerate package-lock.json...${NC}"
        if npm install; then
            echo -e "${GREEN}✓ Successfully regenerated package-lock.json${NC}\n"

            # Stage the new package-lock.json
            git add package-lock.json

            # Check if there are any remaining conflicts
            if git diff --name-only --diff-filter=U | grep -q .; then
                echo -e "${YELLOW}✓ package-lock.json conflict resolved, but other conflicts remain${NC}\n"

                echo -e "${BLUE}Remaining conflicting files:${NC}"
                git status --short | grep "^UU\|^AA\|^DD\|^AU\|^UA"
                echo ""

                echo -e "${BLUE}To resolve remaining conflicts:${NC}"
                echo "1. Edit the conflicting files shown above"
                echo "2. Look for conflict markers: <<<<<<< HEAD, =======, >>>>>>>"
                echo "3. Resolve each conflict and save the files"
                echo "4. Stage resolved files: git add <file>"
                echo "5. Continue the rebase: git rebase --continue"
                echo ""
                echo -e "${BLUE}To abort the rebase:${NC}"
                echo "   git rebase --abort"
                echo ""

                echo -e "${YELLOW}Handing over to you to resolve remaining conflicts...${NC}"
                exit 1
            else
                # No more conflicts, continue the rebase
                echo -e "${GREEN}✓ All conflicts resolved!${NC}"
                echo -e "${BLUE}Continuing rebase...${NC}"

                if git rebase --continue; then
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
                else
                    echo -e "${RED}✗ Failed to complete rebase${NC}"
                    exit 1
                fi
            fi
        else
            echo -e "${RED}✗ npm install failed${NC}"
            echo -e "${YELLOW}Please resolve npm install issues manually${NC}"
            exit 1
        fi
    else
        # No package-lock.json conflicts, show standard conflict resolution instructions
        echo -e "${BLUE}To resolve conflicts:${NC}"
        echo "1. Edit the conflicting files shown above"
        echo "2. Look for conflict markers: <<<<<<< HEAD, =======, >>>>>>>"
        echo "3. Resolve each conflict and save the files"
        echo "4. Stage resolved files: git add <file>"
        echo "5. Continue the rebase: git rebase --continue"
        echo ""
        echo -e "${BLUE}To abort the rebase:${NC}"
        echo "   git rebase --abort"
        echo ""

        echo -e "${YELLOW}Handing over to you to resolve conflicts...${NC}"
        exit 1
    fi
fi
