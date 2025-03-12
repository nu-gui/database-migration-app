#!/bin/bash
# Script to improve code quality in a repository
# Usage: ./improve_code_quality.sh /path/to/repository

set -e

REPO_PATH=$1
QUALITY_LOG="CODE_QUALITY_LOG.md"

if [ -z "$REPO_PATH" ]; then
  echo "Usage: $0 /path/to/repository"
  exit 1
fi

if [ ! -d "$REPO_PATH" ]; then
  echo "Error: $REPO_PATH is not a valid directory"
  exit 1
fi

cd "$REPO_PATH"

# Create or initialize CODE_QUALITY_LOG.md
echo "# Code Quality Improvement Log" > "$QUALITY_LOG"
echo "" >> "$QUALITY_LOG"
echo "This document tracks all code quality improvements performed during repository maintenance." >> "$QUALITY_LOG"
echo "" >> "$QUALITY_LOG"
echo "## Code Quality Improvements" >> "$QUALITY_LOG"
echo "" >> "$QUALITY_LOG"
echo "| Tool | Files Affected | Issues Fixed |" >> "$QUALITY_LOG"
echo "|------|----------------|--------------|" >> "$QUALITY_LOG"

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

# Function to run JavaScript/TypeScript linting and formatting
run_js_linting() {
  local package_manager=$(detect_js_package_manager)
  local files_affected=0
  local issues_fixed=0
  
  echo "Detected JavaScript/TypeScript repository with $package_manager"
  
  # Check if ESLint is configured
  if [ -f ".eslintrc.js" ] || [ -f ".eslintrc.json" ] || [ -f ".eslintrc.yml" ] || [ -f ".eslintrc" ]; then
    echo "Running ESLint..."
    
    # Check if eslint is in package.json scripts
    if grep -q "\"eslint\"" package.json; then
      if [ "$package_manager" = "yarn" ]; then
        yarn eslint --fix . 2>&1 | tee eslint_output.log
      elif [ "$package_manager" = "pnpm" ]; then
        pnpm eslint --fix . 2>&1 | tee eslint_output.log
      else
        npm run eslint --fix . 2>&1 | tee eslint_output.log
      fi
    else
      # Try running eslint directly
      if [ "$package_manager" = "yarn" ]; then
        yarn eslint --fix . 2>&1 | tee eslint_output.log || echo "ESLint failed, may need to be installed"
      elif [ "$package_manager" = "pnpm" ]; then
        pnpm eslint --fix . 2>&1 | tee eslint_output.log || echo "ESLint failed, may need to be installed"
      else
        npx eslint --fix . 2>&1 | tee eslint_output.log || echo "ESLint failed, may need to be installed"
      fi
    fi
    
    # Count affected files and issues fixed
    if [ -f "eslint_output.log" ]; then
      files_affected=$(grep -c "problems" eslint_output.log || echo 0)
      issues_fixed=$(grep -c "fixed" eslint_output.log || echo 0)
      rm eslint_output.log
    fi
    
    echo "| ESLint | $files_affected | $issues_fixed |" >> "$QUALITY_LOG"
  else
    echo "ESLint not configured, skipping"
  fi
  
  # Check if Prettier is configured
  if [ -f ".prettierrc" ] || [ -f ".prettierrc.js" ] || [ -f ".prettierrc.json" ] || [ -f ".prettierrc.yml" ]; then
    echo "Running Prettier..."
    
    # Check if prettier is in package.json scripts
    if grep -q "\"prettier\"" package.json; then
      if [ "$package_manager" = "yarn" ]; then
        yarn prettier --write . 2>&1 | tee prettier_output.log
      elif [ "$package_manager" = "pnpm" ]; then
        pnpm prettier --write . 2>&1 | tee prettier_output.log
      else
        npm run prettier --write . 2>&1 | tee prettier_output.log
      fi
    else
      # Try running prettier directly
      if [ "$package_manager" = "yarn" ]; then
        yarn prettier --write . 2>&1 | tee prettier_output.log || echo "Prettier failed, may need to be installed"
      elif [ "$package_manager" = "pnpm" ]; then
        pnpm prettier --write . 2>&1 | tee prettier_output.log || echo "Prettier failed, may need to be installed"
      else
        npx prettier --write . 2>&1 | tee prettier_output.log || echo "Prettier failed, may need to be installed"
      fi
    fi
    
    # Count affected files
    if [ -f "prettier_output.log" ]; then
      files_affected=$(grep -c "prettier" prettier_output.log || echo 0)
      rm prettier_output.log
    fi
    
    echo "| Prettier | $files_affected | N/A |" >> "$QUALITY_LOG"
  else
    echo "Prettier not configured, skipping"
  fi
  
  # Check if there's a lint script in package.json
  if grep -q "\"lint\"" package.json; then
    echo "Running custom lint script..."
    
    if [ "$package_manager" = "yarn" ]; then
      yarn lint 2>&1 | tee lint_output.log || echo "Lint script failed"
    elif [ "$package_manager" = "pnpm" ]; then
      pnpm lint 2>&1 | tee lint_output.log || echo "Lint script failed"
    else
      npm run lint 2>&1 | tee lint_output.log || echo "Lint script failed"
    fi
    
    echo "| Custom Lint | All JS/TS files | See lint output |" >> "$QUALITY_LOG"
    
    if [ -f "lint_output.log" ]; then
      rm lint_output.log
    fi
  fi
  
  # Check if there's a format script in package.json
  if grep -q "\"format\"" package.json; then
    echo "Running custom format script..."
    
    if [ "$package_manager" = "yarn" ]; then
      yarn format 2>&1 | tee format_output.log || echo "Format script failed"
    elif [ "$package_manager" = "pnpm" ]; then
      pnpm format 2>&1 | tee format_output.log || echo "Format script failed"
    else
      npm run format 2>&1 | tee format_output.log || echo "Format script failed"
    fi
    
    echo "| Custom Format | All JS/TS files | See format output |" >> "$QUALITY_LOG"
    
    if [ -f "format_output.log" ]; then
      rm format_output.log
    fi
  fi
}

# Function to run Python linting and formatting
run_python_linting() {
  local files_affected=0
  local issues_fixed=0
  
  echo "Detected Python repository"
  
  # Check if Black is installed
  if command -v black &> /dev/null; then
    echo "Running Black formatter..."
    black . 2>&1 | tee black_output.log || echo "Black failed, may need to be installed"
    
    if [ -f "black_output.log" ]; then
      files_affected=$(grep -c "reformatted" black_output.log || echo 0)
      rm black_output.log
    fi
    
    echo "| Black | $files_affected | N/A |" >> "$QUALITY_LOG"
  else
    echo "Black not installed, skipping"
  fi
  
  # Check if isort is installed
  if command -v isort &> /dev/null; then
    echo "Running isort..."
    isort . 2>&1 | tee isort_output.log || echo "isort failed, may need to be installed"
    
    if [ -f "isort_output.log" ]; then
      files_affected=$(grep -c "Fixing" isort_output.log || echo 0)
      rm isort_output.log
    fi
    
    echo "| isort | $files_affected | N/A |" >> "$QUALITY_LOG"
  else
    echo "isort not installed, skipping"
  fi
  
  # Check if flake8 is installed
  if command -v flake8 &> /dev/null; then
    echo "Running flake8..."
    flake8 . 2>&1 | tee flake8_output.log || echo "flake8 reported issues"
    
    if [ -f "flake8_output.log" ]; then
      issues_fixed=$(grep -c ":" flake8_output.log || echo 0)
      rm flake8_output.log
    fi
    
    echo "| flake8 | All Python files | $issues_fixed issues identified |" >> "$QUALITY_LOG"
  else
    echo "flake8 not installed, skipping"
  fi
  
  # Check if pylint is installed
  if command -v pylint &> /dev/null; then
    echo "Running pylint..."
    find . -name "*.py" -type f | xargs pylint 2>&1 | tee pylint_output.log || echo "pylint reported issues"
    
    if [ -f "pylint_output.log" ]; then
      issues_fixed=$(grep -c ":" pylint_output.log || echo 0)
      rm pylint_output.log
    fi
    
    echo "| pylint | All Python files | $issues_fixed issues identified |" >> "$QUALITY_LOG"
  else
    echo "pylint not installed, skipping"
  fi
  
  # Check if there's a Makefile with lint target
  if [ -f "Makefile" ] && grep -q "lint:" Makefile; then
    echo "Running make lint..."
    make lint 2>&1 | tee make_lint_output.log || echo "make lint reported issues"
    
    echo "| make lint | All Python files | See make lint output |" >> "$QUALITY_LOG"
    
    if [ -f "make_lint_output.log" ]; then
      rm make_lint_output.log
    fi
  fi
}

# Main execution
repo_type=$(detect_repo_type)

case "$repo_type" in
  javascript)
    run_js_linting
    ;;
  python)
    run_python_linting
    ;;
  unknown)
    echo "Unknown repository type, skipping code quality improvements"
    echo "| N/A | N/A | N/A |" >> "$QUALITY_LOG"
    ;;
esac

echo "Code quality improvements complete. See $QUALITY_LOG for details."
