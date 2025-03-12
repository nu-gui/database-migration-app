#!/bin/bash
# Script to update documentation in a repository
# Usage: ./update_documentation.sh /path/to/repository

set -e

REPO_PATH=$1
DOC_LOG="DOCUMENTATION_UPDATE_LOG.md"

if [ -z "$REPO_PATH" ]; then
  echo "Usage: $0 /path/to/repository"
  exit 1
fi

if [ ! -d "$REPO_PATH" ]; then
  echo "Error: $REPO_PATH is not a valid directory"
  exit 1
fi

cd "$REPO_PATH"

# Create or initialize DOCUMENTATION_UPDATE_LOG.md
echo "# Documentation Update Log" > "$DOC_LOG"
echo "" >> "$DOC_LOG"
echo "This document tracks all documentation updates performed during repository maintenance." >> "$DOC_LOG"
echo "" >> "$DOC_LOG"
echo "## Documentation Updates" >> "$DOC_LOG"
echo "" >> "$DOC_LOG"
echo "| File | Type | Action Taken |" >> "$DOC_LOG"
echo "|------|------|-------------|" >> "$DOC_LOG"

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

# Function to get repository name
get_repo_name() {
  basename "$REPO_PATH"
}

# Function to update or create README.md
update_readme() {
  local repo_name=$(get_repo_name)
  local repo_type=$(detect_repo_type)
  
  if [ -f "README.md" ]; then
    echo "README.md exists, checking for missing sections..."
    
    # Check for missing sections
    local missing_sections=()
    
    if ! grep -q "# $repo_name" README.md && ! grep -q "# $(echo "$repo_name" | tr '[:upper:]' '[:lower:]')" README.md; then
      missing_sections+=("Title")
    fi
    
    if ! grep -q -i "## Description" README.md && ! grep -q -i "## Overview" README.md; then
      missing_sections+=("Description/Overview")
    fi
    
    if ! grep -q -i "## Installation" README.md && ! grep -q -i "## Setup" README.md; then
      missing_sections+=("Installation/Setup")
    fi
    
    if ! grep -q -i "## Usage" README.md; then
      missing_sections+=("Usage")
    fi
    
    if [ ${#missing_sections[@]} -eq 0 ]; then
      echo "README.md contains all required sections"
      echo "| README.md | Documentation | No updates needed |" >> "$DOC_LOG"
    else
      echo "README.md is missing sections: ${missing_sections[*]}"
      echo "| README.md | Documentation | Updated with missing sections: ${missing_sections[*]} |" >> "$DOC_LOG"
      
      # Create a backup
      cp README.md README.md.bak
      
      # Add missing sections
      for section in "${missing_sections[@]}"; do
        case "$section" in
          "Title")
            sed -i "1i# $repo_name\n" README.md
            ;;
          "Description/Overview")
            echo -e "\n## Description\n\nA brief description of the $repo_name project.\n" >> README.md
            ;;
          "Installation/Setup")
            echo -e "\n## Installation\n\n" >> README.md
            
            if [ "$repo_type" = "javascript" ]; then
              echo -e "```bash\n# Clone the repository\ngit clone <repository-url>\ncd $repo_name\n\n# Install dependencies\nnpm install\n```\n" >> README.md
            elif [ "$repo_type" = "python" ]; then
              echo -e "```bash\n# Clone the repository\ngit clone <repository-url>\ncd $repo_name\n\n# Install dependencies\npip install -r requirements.txt\n```\n" >> README.md
            else
              echo -e "Instructions for setting up the project.\n" >> README.md
            fi
            ;;
          "Usage")
            echo -e "\n## Usage\n\nInstructions for using the project.\n" >> README.md
            ;;
        esac
      done
    fi
  else
    echo "README.md does not exist, creating..."
    
    # Create README.md
    cat > README.md << EOL
# $repo_name

## Description

A brief description of the $repo_name project.

## Installation

EOL

    if [ "$repo_type" = "javascript" ]; then
      cat >> README.md << EOL
\`\`\`bash
# Clone the repository
git clone <repository-url>
cd $repo_name

# Install dependencies
npm install
\`\`\`
EOL
    elif [ "$repo_type" = "python" ]; then
      cat >> README.md << EOL
\`\`\`bash
# Clone the repository
git clone <repository-url>
cd $repo_name

# Install dependencies
pip install -r requirements.txt
\`\`\`
EOL
    else
      cat >> README.md << EOL
Instructions for setting up the project.
EOL
    fi

    cat >> README.md << EOL

## Usage

Instructions for using the project.

## Contributing

Guidelines for contributing to the project.

## License

Information about the project's license.
EOL

    echo "| README.md | Documentation | Created new README.md |" >> "$DOC_LOG"
  fi
}

# Function to update or create CHANGELOG.md
update_changelog() {
  local repo_name=$(get_repo_name)
  local current_date=$(date +"%Y-%m-%d")
  
  if [ -f "CHANGELOG.md" ]; then
    echo "CHANGELOG.md exists, checking for updates..."
    
    # Check if maintenance entry exists
    if grep -q "$current_date.*Repository maintenance" CHANGELOG.md; then
      echo "CHANGELOG.md already has an entry for today's maintenance"
      echo "| CHANGELOG.md | Documentation | No updates needed |" >> "$DOC_LOG"
    else
      echo "Adding maintenance entry to CHANGELOG.md"
      
      # Create a backup
      cp CHANGELOG.md CHANGELOG.md.bak
      
      # Add maintenance entry
      sed -i "1i## [$current_date] - Repository maintenance\n\n- Standardized file and folder naming\n- Improved code quality\n- Updated dependencies\n- Enhanced security\n- Updated documentation\n" CHANGELOG.md
      
      echo "| CHANGELOG.md | Documentation | Added maintenance entry |" >> "$DOC_LOG"
    fi
  else
    echo "CHANGELOG.md does not exist, creating..."
    
    # Create CHANGELOG.md
    cat > CHANGELOG.md << EOL
# Changelog

All notable changes to this project will be documented in this file.

## [$current_date] - Repository maintenance

- Standardized file and folder naming
- Improved code quality
- Updated dependencies
- Enhanced security
- Updated documentation

## [Unreleased]

- Initial project setup
EOL

    echo "| CHANGELOG.md | Documentation | Created new CHANGELOG.md |" >> "$DOC_LOG"
  fi
}

# Function to create RENAME_LOG.md if it doesn't exist
ensure_rename_log() {
  if [ ! -f "RENAME_LOG.md" ]; then
    echo "Creating RENAME_LOG.md..."
    
    cat > RENAME_LOG.md << EOL
# File and Folder Rename Log

This document tracks all file and folder renames performed during repository maintenance.

## Renamed Files and Folders

| Old Name | New Name | Affected Files | Steps Taken |
|----------|----------|----------------|-------------|
EOL

    echo "| RENAME_LOG.md | Documentation | Created new RENAME_LOG.md |" >> "$DOC_LOG"
  else
    echo "RENAME_LOG.md already exists"
    echo "| RENAME_LOG.md | Documentation | No updates needed |" >> "$DOC_LOG"
  fi
}

# Function to update or create .gitignore
update_gitignore() {
  local repo_type=$(detect_repo_type)
  
  if [ -f ".gitignore" ]; then
    echo ".gitignore exists, checking for common entries..."
    
    # Common entries to check
    local common_entries=()
    
    # Common entries for all repositories
    common_entries+=(".DS_Store")
    common_entries+=("*.log")
    common_entries+=(".env")
    common_entries+=(".env.local")
    common_entries+=("*.bak")
    
    # Repository-specific entries
    if [ "$repo_type" = "javascript" ]; then
      common_entries+=("node_modules/")
      common_entries+=("dist/")
      common_entries+=("build/")
      common_entries+=("coverage/")
      common_entries+=(".cache/")
    elif [ "$repo_type" = "python" ]; then
      common_entries+=("__pycache__/")
      common_entries+=("*.py[cod]")
      common_entries+=("*$py.class")
      common_entries+=("venv/")
      common_entries+=("env/")
      common_entries+=(".pytest_cache/")
      common_entries+=(".coverage")
    fi
    
    # Check and add missing entries
    local missing_entries=()
    for entry in "${common_entries[@]}"; do
      if ! grep -q "^$entry$" .gitignore; then
        missing_entries+=("$entry")
        echo "$entry" >> .gitignore
      fi
    done
    
    if [ ${#missing_entries[@]} -eq 0 ]; then
      echo ".gitignore contains all common entries"
      echo "| .gitignore | Configuration | No updates needed |" >> "$DOC_LOG"
    else
      echo "Added missing entries to .gitignore: ${missing_entries[*]}"
      echo "| .gitignore | Configuration | Added missing entries: ${missing_entries[*]} |" >> "$DOC_LOG"
    fi
  else
    echo ".gitignore does not exist, creating..."
    
    # Create .gitignore with common entries
    cat > .gitignore << EOL
# OS generated files
.DS_Store
Thumbs.db
ehthumbs.db
Desktop.ini

# Editor files
*.swp
*.swo
*~
.vscode/
.idea/

# Environment files
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Backup files
*.bak
EOL

    # Add repository-specific entries
    if [ "$repo_type" = "javascript" ]; then
      cat >> .gitignore << EOL

# JavaScript/TypeScript
node_modules/
dist/
build/
coverage/
.cache/
.npm
.eslintcache
.yarn-integrity
EOL
    elif [ "$repo_type" = "python" ]; then
      cat >> .gitignore << EOL

# Python
__pycache__/
*.py[cod]
*$py.class
venv/
env/
.env/
.venv/
ENV/
.pytest_cache/
.coverage
htmlcov/
.tox/
.nox/
.hypothesis/
EOL
    fi
    
    echo "| .gitignore | Configuration | Created new .gitignore |" >> "$DOC_LOG"
  fi
}

# Main execution
update_readme
update_changelog
ensure_rename_log
update_gitignore

echo "Documentation updates complete. See $DOC_LOG for details."
