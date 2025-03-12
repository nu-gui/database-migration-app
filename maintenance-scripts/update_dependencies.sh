#!/bin/bash
# Script to update dependencies in a repository
# Usage: ./update_dependencies.sh /path/to/repository

set -e

REPO_PATH=$1
DEPENDENCY_LOG="DEPENDENCY_UPDATE_LOG.md"

if [ -z "$REPO_PATH" ]; then
  echo "Usage: $0 /path/to/repository"
  exit 1
fi

if [ ! -d "$REPO_PATH" ]; then
  echo "Error: $REPO_PATH is not a valid directory"
  exit 1
fi

cd "$REPO_PATH"

# Create or initialize DEPENDENCY_UPDATE_LOG.md
echo "# Dependency Update Log" > "$DEPENDENCY_LOG"
echo "" >> "$DEPENDENCY_LOG"
echo "This document tracks all dependency updates performed during repository maintenance." >> "$DEPENDENCY_LOG"
echo "" >> "$DEPENDENCY_LOG"
echo "## Updated Dependencies" >> "$DEPENDENCY_LOG"
echo "" >> "$DEPENDENCY_LOG"
echo "| Package Manager | Package | Old Version | New Version |" >> "$DEPENDENCY_LOG"
echo "|----------------|---------|-------------|-------------|" >> "$DEPENDENCY_LOG"

# Function to detect repository type
detect_repo_type() {
  if [ -f "package.json" ]; then
    echo "javascript"
  elif [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
    echo "python"
  else
    echo "unknown"
  fi
}

# Function to detect package manager for JavaScript repositories
detect_js_package_manager() {
  if [ -f "yarn.lock" ]; then
    echo "yarn"
  elif [ -f "pnpm-lock.yaml" ]; then
    echo "pnpm"
  else
    echo "npm"
  fi
}

# Function to update JavaScript/TypeScript dependencies
update_js_dependencies() {
  local package_manager=$(detect_js_package_manager)
  
  echo "Detected JavaScript/TypeScript repository with $package_manager"
  
  # Create a backup of package.json
  cp package.json package.json.bak
  
  # Check for outdated packages
  echo "Checking for outdated packages..."
  
  if [ "$package_manager" = "yarn" ]; then
    yarn outdated --json > outdated.json 2>/dev/null || echo "No outdated packages found"
    
    # Update dependencies
    echo "Updating dependencies..."
    yarn upgrade 2>&1 | tee upgrade_output.log
    
  elif [ "$package_manager" = "pnpm" ]; then
    pnpm outdated --json > outdated.json 2>/dev/null || echo "No outdated packages found"
    
    # Update dependencies
    echo "Updating dependencies..."
    pnpm update 2>&1 | tee upgrade_output.log
    
  else
    npm outdated --json > outdated.json 2>/dev/null || echo "No outdated packages found"
    
    # Update dependencies
    echo "Updating dependencies..."
    npm update 2>&1 | tee upgrade_output.log
  fi
  
  # Parse outdated.json and log updates
  if [ -f "outdated.json" ] && [ -s "outdated.json" ]; then
    # Extract package names, current versions, and latest versions
    if [ "$package_manager" = "yarn" ]; then
      # Yarn format is different
      cat outdated.json | grep -E '"name"|"current"|"latest"' | sed 's/[",:]//g' | sed 's/^ *//' | 
      awk 'BEGIN{OFS="\t"} 
           /name/{name=$2} 
           /current/{current=$2} 
           /latest/{latest=$2; print name, current, latest}' | 
      while read -r package current latest; do
        echo "| $package_manager | $package | $current | $latest |" >> "$DEPENDENCY_LOG"
      done
    else
      # npm/pnpm format
      cat outdated.json | jq -r '.[] | "\(.name)\t\(.current)\t\(.latest)"' 2>/dev/null |
      while read -r package current latest; do
        echo "| $package_manager | $package | $current | $latest |" >> "$DEPENDENCY_LOG"
      done
    fi
  else
    echo "| $package_manager | No outdated packages found | N/A | N/A |" >> "$DEPENDENCY_LOG"
  fi
  
  # Clean up
  if [ -f "outdated.json" ]; then
    rm outdated.json
  fi
  
  if [ -f "upgrade_output.log" ]; then
    rm upgrade_output.log
  fi
}

# Function to update Python dependencies
update_python_dependencies() {
  echo "Detected Python repository"
  
  # Check if pip is available
  if ! command -v pip &> /dev/null; then
    echo "pip not found, skipping dependency updates"
    echo "| pip | pip not found | N/A | N/A |" >> "$DEPENDENCY_LOG"
    return
  fi
  
  # Check for requirements.txt
  if [ -f "requirements.txt" ]; then
    echo "Found requirements.txt, checking for outdated packages..."
    
    # Create a backup
    cp requirements.txt requirements.txt.bak
    
    # Get outdated packages
    pip list --outdated --format=json > pip_outdated.json 2>/dev/null || echo "Error checking outdated packages"
    
    # Parse outdated packages and update requirements.txt
    if [ -f "pip_outdated.json" ] && [ -s "pip_outdated.json" ]; then
      cat pip_outdated.json | jq -r '.[] | "\(.name)\t\(.version)\t\(.latest_version)"' 2>/dev/null |
      while read -r package current latest; do
        # Update the version in requirements.txt
        if grep -q "^$package==" requirements.txt; then
          sed -i "s/^$package==$current/$package==$latest/" requirements.txt
          echo "| pip (requirements.txt) | $package | $current | $latest |" >> "$DEPENDENCY_LOG"
        elif grep -q "^$package>=" requirements.txt; then
          sed -i "s/^$package>=[0-9.]*/$package>=$latest/" requirements.txt
          echo "| pip (requirements.txt) | $package | >=$current | >=$latest |" >> "$DEPENDENCY_LOG"
        elif grep -q "^$package" requirements.txt; then
          sed -i "s/^$package/$package==$latest/" requirements.txt
          echo "| pip (requirements.txt) | $package | unspecified | $latest |" >> "$DEPENDENCY_LOG"
        fi
      done
    else
      echo "| pip (requirements.txt) | No outdated packages found | N/A | N/A |" >> "$DEPENDENCY_LOG"
    fi
  fi
  
  # Check for pyproject.toml
  if [ -f "pyproject.toml" ]; then
    echo "Found pyproject.toml, checking for outdated packages..."
    
    # Create a backup
    cp pyproject.toml pyproject.toml.bak
    
    # Check if poetry is available
    if command -v poetry &> /dev/null; then
      echo "Poetry detected, updating dependencies..."
      poetry update 2>&1 | tee poetry_update.log
      
      # Extract updated packages from log
      if [ -f "poetry_update.log" ]; then
        grep "Updating" poetry_update.log | sed 's/Updating //' | sed 's/ to /,/' |
        while IFS=',' read -r package_version new_version; do
          package=$(echo "$package_version" | cut -d' ' -f1)
          old_version=$(echo "$package_version" | cut -d' ' -f2)
          echo "| poetry | $package | $old_version | $new_version |" >> "$DEPENDENCY_LOG"
        done
        
        rm poetry_update.log
      fi
    else
      echo "Poetry not found, skipping pyproject.toml updates"
      echo "| poetry | Poetry not found | N/A | N/A |" >> "$DEPENDENCY_LOG"
    fi
  fi
  
  # Clean up
  if [ -f "pip_outdated.json" ]; then
    rm pip_outdated.json
  fi
}

# Main execution
repo_type=$(detect_repo_type)

case "$repo_type" in
  javascript)
    update_js_dependencies
    ;;
  python)
    update_python_dependencies
    ;;
  unknown)
    echo "Unknown repository type, skipping dependency updates"
    echo "| N/A | Unknown repository type | N/A | N/A |" >> "$DEPENDENCY_LOG"
    ;;
esac

echo "Dependency updates complete. See $DEPENDENCY_LOG for details."
