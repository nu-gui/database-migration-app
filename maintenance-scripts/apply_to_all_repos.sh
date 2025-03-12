#!/bin/bash
# Script to apply maintenance to all repositories
# Usage: ./apply_to_all_repos.sh

set -e

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Function to list repositories
list_repositories() {
  # List all repositories in the nu-gui organization
  if command -v gh &> /dev/null; then
    gh repo list nu-gui --limit 100 --json name --jq '.[].name'
  else
    echo "GitHub CLI not found, please provide repository names manually"
    return 1
  fi
}

# Function to clone a repository
clone_repository() {
  local repo_name=$1
  local clone_dir="$SCRIPT_DIR/../repos/$repo_name"
  
  echo "Cloning repository: nu-gui/$repo_name"
  
  # Check if directory already exists
  if [ -d "$clone_dir" ]; then
    echo "Repository already cloned at $clone_dir"
    return 0
  fi
  
  # Create parent directory
  mkdir -p "$SCRIPT_DIR/../repos"
  
  # Clone the repository
  if command -v gh &> /dev/null; then
    gh repo clone "nu-gui/$repo_name" "$clone_dir"
    return $?
  else
    echo "GitHub CLI not found, please clone the repository manually"
    return 1
  fi
}

# Function to apply maintenance to a repository
apply_maintenance() {
  local repo_name=$1
  local repo_path="$SCRIPT_DIR/../repos/$repo_name"
  
  echo "Applying maintenance to repository: $repo_name"
  
  # Check if repository exists
  if [ ! -d "$repo_path" ]; then
    echo "Repository not found at $repo_path"
    return 1
  fi
  
  # Apply maintenance
  "$SCRIPT_DIR/maintain_repository.sh" "$repo_path"
  
  return $?
}

# Main execution
echo "Starting maintenance for all repositories..."

# Get list of repositories
echo "Getting list of repositories..."
repos=$(list_repositories)

if [ $? -ne 0 ]; then
  echo "Failed to get repository list, exiting"
  exit 1
fi

# Process each repository
for repo in $repos; do
  echo "Processing repository: $repo"
  
  # Clone the repository
  clone_repository "$repo"
  
  if [ $? -ne 0 ]; then
    echo "Failed to clone repository: $repo, skipping"
    continue
  fi
  
  # Apply maintenance
  apply_maintenance "$repo"
  
  if [ $? -ne 0 ]; then
    echo "Failed to apply maintenance to repository: $repo"
  else
    echo "Maintenance applied successfully to repository: $repo"
  fi
  
  echo "-----------------------------------"
done

echo "Maintenance for all repositories complete"
