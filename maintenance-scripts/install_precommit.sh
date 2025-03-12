#!/bin/bash
# Script to install pre-commit hooks in a repository
# Usage: ./install_precommit.sh /path/to/repository

set -e

REPO_PATH=$1

if [ -z "$REPO_PATH" ]; then
  echo "Usage: $0 /path/to/repository"
  exit 1
fi

if [ ! -d "$REPO_PATH" ]; then
  echo "Error: $REPO_PATH is not a valid directory"
  exit 1
fi

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd "$REPO_PATH"

# Copy pre-commit config
cp "$SCRIPT_DIR/precommit_config.yaml" .pre-commit-config.yaml

# Install pre-commit if not already installed
if ! command -v pre-commit &> /dev/null; then
  echo "Installing pre-commit..."
  pip install pre-commit
fi

# Install the hooks
pre-commit install

echo "Pre-commit hooks installed successfully in $REPO_PATH"
