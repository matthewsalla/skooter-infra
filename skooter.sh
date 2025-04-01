#!/bin/bash
set -e

# Usage function prints the script usage and exits
usage() {
  echo "Usage: $0 [init|update]"
  echo "  init   - Perform one-time setup: clone template, rename remote, add origin, and push to Gitea"
  echo "  update - Update your thin repo with changes from the template"
  exit 1
}

# Ensure exactly one argument is provided
if [ "$#" -ne 1 ]; then
  usage
fi

# Set mode based on user argument
MODE="$1"

# Repository URLs (customize these if necessary)
GITHUB_TEMPLATE="git@github.com:matthewsalla/skooter-infra.git"
GITEA_REPO="git@git.github.com:exampleorg/skooter-example-org-infra.git"

if [ "$MODE" == "init" ]; then
  echo "=== PHASE 1: Initial Setup ==="
  echo "Cloning the GitHub template repository..."
  git clone "$GITHUB_TEMPLATE"
  
  # Extract directory name from the GITHUB_TEMPLATE URL
  TEMPLATE_DIR=$(basename -s .git "$GITHUB_TEMPLATE")
  cd "$TEMPLATE_DIR"
  
  echo "Renaming origin to upstream..."
  git remote rename origin upstream
  
  echo "Adding Gitea thin repo as new origin..."
  git remote add origin "$GITEA_REPO"
  
  echo "Current remotes:"
  git remote -v
  
  echo "Pushing to Gitea (thin repo initialization)..."
  git push -u origin main
  echo "Initial setup complete."
  
elif [ "$MODE" == "update" ]; then
  echo "=== PHASE 2: Update from Template ==="
  echo "Cloning your Gitea thin repo..."
  git clone "$GITEA_REPO"
  
  # Extract directory name from the GITEA_REPO URL
  REPO_DIR=$(basename -s .git "$GITEA_REPO")
  cd "$REPO_DIR"
  
  echo "Updating submodules..."
  git submodule update --init --recursive
  
  echo "Adding GitHub template as upstream..."
  git remote add upstream "$GITHUB_TEMPLATE"
  
  echo "Fetching updates from upstream..."
  git fetch upstream
  
  echo "Merging upstream/main into your branch..."
  git merge upstream/main
  
  echo "Pushing merged updates to origin..."
  git push origin main
  echo "Update complete."
  
else
  usage
fi
