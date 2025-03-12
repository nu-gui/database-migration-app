#!/bin/bash
# Main script to maintain a repository
# Usage: ./maintain_repository.sh /path/to/repository

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

# Create a timestamp for the branch name
TIMESTAMP=$(date +%s)

# Function to detect repository type
detect_repo_type() {
  if [ -f "$REPO_PATH/package.json" ]; then
    echo "javascript"
  elif [ -f "$REPO_PATH/pyproject.toml" ] || [ -f "$REPO_PATH/setup.py" ] || [ -f "$REPO_PATH/requirements.txt" ]; then
    echo "python"
  else
    echo "unknown"
  fi
}

# Function to create a maintenance branch
create_maintenance_branch() {
  cd "$REPO_PATH"
  
  # Check if git repository
  if [ ! -d ".git" ]; then
    echo "Error: $REPO_PATH is not a git repository"
    return 1
  fi
  
  # Get the default branch
  DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
  
  # Checkout the default branch
  git checkout "$DEFAULT_BRANCH"
  
  # Pull the latest changes
  git pull origin "$DEFAULT_BRANCH"
  
  # Create a new branch
  BRANCH_NAME="fix-repo-maintenance-$TIMESTAMP"
  git checkout -b "$BRANCH_NAME"
  
  echo "Created branch: $BRANCH_NAME"
  return 0
}

# Function to commit changes
commit_changes() {
  cd "$REPO_PATH"
  
  # Check if there are changes to commit
  if git status --porcelain | grep -q .; then
    # Add specific files and directories
    git add maintenance-scripts/
    git add .github/workflows/code-quality.yml
    git add RENAME_LOG.md CODE_QUALITY_LOG.md DEPENDENCY_UPDATE_LOG.md SECURITY_ENHANCEMENT_LOG.md DOCUMENTATION_UPDATE_LOG.md
    git add README.md CHANGELOG.md .gitignore
    
    # Add any renamed files
    git status --porcelain | grep -E '^R|^M|^A' | awk '{print $2}' | xargs -r git add
    
    git commit -m "Fix: Repository maintenance and file naming updates"
    echo "Changes committed"
    return 0
  else
    echo "No changes to commit"
    return 1
  fi
}

# Function to create a pull request
create_pull_request() {
  cd "$REPO_PATH"
  
  # Get the current branch
  BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
  
  # Get the default branch
  DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
  
  # Push the branch
  git push origin "$BRANCH_NAME"
  
  # Create a PR description
  PR_DESCRIPTION="# Repository Maintenance

This PR includes the following improvements:

- Standardized file and folder naming conventions
- Improved code quality through linting and formatting
- Updated dependencies to latest compatible versions
- Enhanced security by identifying potential issues
- Updated documentation

## Changes Made

- See RENAME_LOG.md for details on file and folder renames
- See CODE_QUALITY_LOG.md for details on code quality improvements
- See DEPENDENCY_UPDATE_LOG.md for details on dependency updates
- See SECURITY_ENHANCEMENT_LOG.md for details on security enhancements
- See DOCUMENTATION_UPDATE_LOG.md for details on documentation updates

## Link to Devin run
https://app.devin.ai/sessions/9813ee06579342c7a6fa2d78435751a5

## Requested by
wes@zyongate.com"

  # Create a temporary file for the PR description
  PR_DESC_FILE=$(mktemp)
  echo "$PR_DESCRIPTION" > "$PR_DESC_FILE"
  
  # Create the PR
  if command -v gh &> /dev/null; then
    gh pr create --base "$DEFAULT_BRANCH" --head "$BRANCH_NAME" --title "Fix: Repository maintenance and file naming updates" --body-file "$PR_DESC_FILE"
    echo "Pull request created"
  else
    echo "GitHub CLI not found, please create a pull request manually"
  fi
  
  # Clean up
  rm "$PR_DESC_FILE"
}

# Function to copy maintenance scripts to the repository
copy_maintenance_scripts() {
  echo "Copying maintenance scripts to the repository..."
  
  # Create a maintenance directory in the repository
  mkdir -p "$REPO_PATH/maintenance-scripts"
  
  # Copy all scripts
  cp "$SCRIPT_DIR"/*.sh "$REPO_PATH/maintenance-scripts/"
  
  # Make them executable
  chmod +x "$REPO_PATH/maintenance-scripts"/*.sh
  
  echo "Maintenance scripts copied to $REPO_PATH/maintenance-scripts/"
}

# Function to create GitHub Actions workflow for maintenance
create_github_actions_workflow() {
  echo "Creating GitHub Actions workflow for maintenance..."
  
  # Create the workflows directory if it doesn't exist
  mkdir -p "$REPO_PATH/.github/workflows"
  
  # Determine the repository type
  REPO_TYPE=$(detect_repo_type)
  
  # Create the workflow file based on repository type
  if [ "$REPO_TYPE" = "javascript" ]; then
    cat > "$REPO_PATH/.github/workflows/code-quality.yml" << EOL
name: Code Quality

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Lint
        run: npm run lint
        
      - name: Format check
        run: npm run format:check || npm run format -- --check
        
      - name: AutoFix Code
        uses: autofix-ci/action@v1
EOL
  elif [ "$REPO_TYPE" = "python" ]; then
    cat > "$REPO_PATH/.github/workflows/code-quality.yml" << EOL
name: Code Quality

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'
          
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install black isort flake8
          if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
          if [ -f requirements-dev.txt ]; then pip install -r requirements-dev.txt; fi
      
      - name: Check formatting with Black
        run: black --check .
        
      - name: Check imports with isort
        run: isort --check-only --profile black .
        
      - name: Lint with flake8
        run: flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics
        
      - name: AutoFix Code
        uses: autofix-ci/action@v1
EOL
  else
    cat > "$REPO_PATH/.github/workflows/code-quality.yml" << EOL
name: Code Quality

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: AutoFix Code
        uses: autofix-ci/action@v1
EOL
  fi
  
  echo "GitHub Actions workflow created at $REPO_PATH/.github/workflows/code-quality.yml"
}

# Main execution
echo "Starting repository maintenance for $REPO_PATH..."

# Step 1: Create a maintenance branch
echo "Step 1: Creating maintenance branch..."
if ! create_maintenance_branch; then
  echo "Failed to create maintenance branch, exiting"
  exit 1
fi

# Step 2: Copy maintenance scripts to the repository
echo "Step 2: Copying maintenance scripts..."
copy_maintenance_scripts

# Step 3: Create GitHub Actions workflow
echo "Step 3: Creating GitHub Actions workflow..."
create_github_actions_workflow

# Step 4: Standardize file and folder names
echo "Step 4: Standardizing file and folder names..."
"$SCRIPT_DIR/standardize_filenames.sh" "$REPO_PATH"

# Step 5: Improve code quality
echo "Step 5: Improving code quality..."
"$SCRIPT_DIR/improve_code_quality.sh" "$REPO_PATH"

# Step 6: Update dependencies
echo "Step 6: Updating dependencies..."
"$SCRIPT_DIR/update_dependencies.sh" "$REPO_PATH"

# Step 7: Enhance security
echo "Step 7: Enhancing security..."
"$SCRIPT_DIR/enhance_security.sh" "$REPO_PATH"

# Step 8: Update documentation
echo "Step 8: Updating documentation..."
"$SCRIPT_DIR/update_documentation.sh" "$REPO_PATH"

# Step 9: Commit changes
echo "Step 9: Committing changes..."
commit_changes

# Step 10: Create a pull request
echo "Step 10: Creating pull request..."
create_pull_request

echo "Repository maintenance complete for $REPO_PATH"
