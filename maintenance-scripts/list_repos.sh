#!/bin/bash
# Script to list repositories in the nu-gui organization
# Usage: ./list_repos.sh

set -e

# Function to list repositories
list_repositories() {
  # List all repositories in the nu-gui organization
  if command -v gh &> /dev/null; then
    echo "Repositories in nu-gui organization:"
    gh repo list nu-gui --limit 100 --json name,description --jq '.[] | "\(.name) - \(.description)"'
  else
    echo "GitHub CLI not found, please install it to list repositories"
    return 1
  fi
}

# Main execution
list_repositories
