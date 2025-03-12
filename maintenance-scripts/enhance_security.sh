#!/bin/bash
# Script to enhance security in a repository
# Usage: ./enhance_security.sh /path/to/repository

set -e

REPO_PATH=$1
SECURITY_LOG="SECURITY_ENHANCEMENT_LOG.md"

if [ -z "$REPO_PATH" ]; then
  echo "Usage: $0 /path/to/repository"
  exit 1
fi

if [ ! -d "$REPO_PATH" ]; then
  echo "Error: $REPO_PATH is not a valid directory"
  exit 1
fi

cd "$REPO_PATH"

# Create or initialize SECURITY_ENHANCEMENT_LOG.md
echo "# Security Enhancement Log" > "$SECURITY_LOG"
echo "" >> "$SECURITY_LOG"
echo "This document tracks all security enhancements performed during repository maintenance." >> "$SECURITY_LOG"
echo "" >> "$SECURITY_LOG"
echo "## Security Enhancements" >> "$SECURITY_LOG"
echo "" >> "$SECURITY_LOG"
echo "| Category | Issue | Location | Action Taken |" >> "$SECURITY_LOG"
echo "|----------|-------|----------|-------------|" >> "$SECURITY_LOG"

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

# Function to scan for hardcoded secrets
scan_for_secrets() {
  echo "Scanning for hardcoded secrets..."
  
  # Common patterns for secrets
  local patterns=(
    "password[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
    "passwd[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
    "pwd[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
    "secret[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
    "token[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
    "api[_-]?key[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
    "access[_-]?key[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
    "auth[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
    "credentials[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
    "BEGIN (RSA|DSA|EC|OPENSSH) PRIVATE KEY"
  )
  
  # Files to exclude
  local exclude_dirs=(
    ".git"
    "node_modules"
    "venv"
    "env"
    ".env"
    "dist"
    "build"
    "__pycache__"
  )
  
  # Build exclude pattern
  local exclude_pattern=""
  for dir in "${exclude_dirs[@]}"; do
    exclude_pattern="$exclude_pattern --exclude-dir=$dir"
  done
  
  # Scan for each pattern
  for pattern in "${patterns[@]}"; do
    echo "Scanning for pattern: $pattern"
    
    grep -r $exclude_pattern --include="*.{js,jsx,ts,tsx,py,json,yml,yaml,xml,properties,config,ini,env}" -E "$pattern" . 2>/dev/null | while read -r match; do
      file=$(echo "$match" | cut -d: -f1)
      line_content=$(echo "$match" | cut -d: -f2-)
      
      # Skip if it's in a test file or example file
      if [[ "$file" == *"test"* ]] || [[ "$file" == *"example"* ]] || [[ "$file" == *"mock"* ]]; then
        continue
      fi
      
      # Skip if it's a commented line
      if [[ "$line_content" == *"///"* ]] || [[ "$line_content" == *"#"* ]] || [[ "$line_content" == *"/*"* ]]; then
        continue
      fi
      
      echo "Potential secret found in $file: $line_content"
      echo "| Hardcoded Secret | Potential secret/credential | $file | Flagged for review |" >> "$SECURITY_LOG"
    done
  done
}

# Function to check for vulnerable dependencies in JavaScript repositories
check_js_vulnerabilities() {
  local package_manager=$(detect_js_package_manager)
  
  echo "Checking for vulnerable dependencies with $package_manager..."
  
  if [ "$package_manager" = "yarn" ]; then
    yarn audit --json > yarn_audit.json 2>/dev/null || echo "Yarn audit failed or found vulnerabilities"
    
    if [ -f "yarn_audit.json" ] && [ -s "yarn_audit.json" ]; then
      # Parse yarn audit output
      cat yarn_audit.json | grep -E '"package"|"severity"|"title"' | sed 's/[",:]//g' | sed 's/^ *//' | 
      awk 'BEGIN{OFS="\t"} 
           /package/{package=$2} 
           /severity/{severity=$2} 
           /title/{title=$2; print package, severity, title}' | 
      while read -r package severity title; do
        echo "| Vulnerable Dependency | $severity: $title | $package | Flagged for update |" >> "$SECURITY_LOG"
      done
    else
      echo "| Vulnerable Dependency | No vulnerabilities found | N/A | N/A |" >> "$SECURITY_LOG"
    fi
    
    rm -f yarn_audit.json
    
  elif [ "$package_manager" = "pnpm" ]; then
    pnpm audit --json > pnpm_audit.json 2>/dev/null || echo "PNPM audit failed or found vulnerabilities"
    
    if [ -f "pnpm_audit.json" ] && [ -s "pnpm_audit.json" ]; then
      # Parse pnpm audit output
      cat pnpm_audit.json | jq -r '.advisories[] | "\(.module_name)\t\(.severity)\t\(.title)"' 2>/dev/null |
      while read -r package severity title; do
        echo "| Vulnerable Dependency | $severity: $title | $package | Flagged for update |" >> "$SECURITY_LOG"
      done
    else
      echo "| Vulnerable Dependency | No vulnerabilities found | N/A | N/A |" >> "$SECURITY_LOG"
    fi
    
    rm -f pnpm_audit.json
    
  else
    npm audit --json > npm_audit.json 2>/dev/null || echo "NPM audit failed or found vulnerabilities"
    
    if [ -f "npm_audit.json" ] && [ -s "npm_audit.json" ]; then
      # Parse npm audit output
      cat npm_audit.json | jq -r '.advisories | to_entries[] | .value | "\(.module_name)\t\(.severity)\t\(.title)"' 2>/dev/null |
      while read -r package severity title; do
        echo "| Vulnerable Dependency | $severity: $title | $package | Flagged for update |" >> "$SECURITY_LOG"
      done
    else
      echo "| Vulnerable Dependency | No vulnerabilities found | N/A | N/A |" >> "$SECURITY_LOG"
    fi
    
    rm -f npm_audit.json
  fi
}

# Function to check for vulnerable dependencies in Python repositories
check_python_vulnerabilities() {
  echo "Checking for vulnerable dependencies in Python repository..."
  
  # Check if safety is installed
  if command -v safety &> /dev/null; then
    echo "Using safety to check for vulnerabilities..."
    
    if [ -f "requirements.txt" ]; then
      safety check -r requirements.txt --json > safety_output.json 2>/dev/null || echo "Safety check failed or found vulnerabilities"
      
      if [ -f "safety_output.json" ] && [ -s "safety_output.json" ]; then
        # Parse safety output
        cat safety_output.json | jq -r '.[] | "\(.[0])\t\(.[1])\t\(.[2])"' 2>/dev/null |
        while read -r package version vulnerability; do
          echo "| Vulnerable Dependency | $vulnerability | $package $version | Flagged for update |" >> "$SECURITY_LOG"
        done
      else
        echo "| Vulnerable Dependency | No vulnerabilities found | N/A | N/A |" >> "$SECURITY_LOG"
      fi
      
      rm -f safety_output.json
    else
      echo "| Vulnerable Dependency | requirements.txt not found | N/A | N/A |" >> "$SECURITY_LOG"
    fi
  else
    echo "safety not installed, skipping Python vulnerability check"
    echo "| Vulnerable Dependency | safety not installed | N/A | N/A |" >> "$SECURITY_LOG"
  fi
}

# Function to check for insecure configurations
check_insecure_configs() {
  echo "Checking for insecure configurations..."
  
  # Check for .env files
  if [ -f ".env" ]; then
    echo "Found .env file, checking if it's in .gitignore..."
    
    if [ -f ".gitignore" ]; then
      if ! grep -q "^\.env$" .gitignore; then
        echo "| Insecure Configuration | .env file not in .gitignore | .gitignore | Added .env to .gitignore |" >> "$SECURITY_LOG"
        echo ".env" >> .gitignore
        echo "Added .env to .gitignore"
      else
        echo ".env is properly ignored in .gitignore"
      fi
    else
      echo "| Insecure Configuration | No .gitignore file | Repository root | Created .gitignore with .env |" >> "$SECURITY_LOG"
      echo ".env" > .gitignore
      echo "Created .gitignore with .env entry"
    fi
  fi
  
  # Check for insecure CORS settings
  grep -r --include="*.{js,py,ts,jsx,tsx}" -E "Access-Control-Allow-Origin: ['\"]?\*['\"]?" . 2>/dev/null | while read -r match; do
    file=$(echo "$match" | cut -d: -f1)
    echo "| Insecure Configuration | Wildcard CORS policy | $file | Flagged for review |" >> "$SECURITY_LOG"
  done
  
  # Check for disabled SSL verification
  grep -r --include="*.{js,py,ts,jsx,tsx}" -E "(verify|verify_ssl|rejectUnauthorized|checkServerIdentity)[[:space:]]*=[[:space:]]*(false|False|0|none|None)" . 2>/dev/null | while read -r match; do
    file=$(echo "$match" | cut -d: -f1)
    echo "| Insecure Configuration | Disabled SSL verification | $file | Flagged for review |" >> "$SECURITY_LOG"
  done
}

# Main execution
repo_type=$(detect_repo_type)

# Scan for hardcoded secrets in all repository types
scan_for_secrets

# Check for insecure configurations in all repository types
check_insecure_configs

# Check for vulnerable dependencies based on repository type
case "$repo_type" in
  javascript)
    check_js_vulnerabilities
    ;;
  python)
    check_python_vulnerabilities
    ;;
  unknown)
    echo "Unknown repository type, skipping vulnerability check"
    echo "| Vulnerable Dependency | Unknown repository type | N/A | N/A |" >> "$SECURITY_LOG"
    ;;
esac

echo "Security enhancements complete. See $SECURITY_LOG for details."
