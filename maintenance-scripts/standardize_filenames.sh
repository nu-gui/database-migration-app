#!/bin/bash

# Script to standardize file and folder names in a repository
# - Converts all file and folder names to lowercase
# - Removes spaces in filenames (using underscores or hyphens instead)
# - Updates references to renamed files in code and documentation

set -e

RENAME_LOG="RENAME_LOG.md"

# Initialize rename log
if [ ! -f "$RENAME_LOG" ]; then
  cat > "$RENAME_LOG" << 'EOL'
# File and Folder Rename Log

This document tracks all file and folder renames performed during repository maintenance.

## Renamed Files and Folders

| Original Path | New Path | Affected Files | Actions Taken | 
|---------------|----------|----------------|--------------|
EOL
fi

# Function to standardize a name
standardize_name() {
  local name="$1"
  # Convert to lowercase and replace spaces with underscores
  echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_'
}

# Function to find references to a file or folder
find_references() {
  local name="$1"
  local escaped=$(echo "$name" | sed 's/[\/&]/\\&/g')
  grep -l -r --include="*.*" "$escaped" . 2>/dev/null || true
}

# Function to update references to renamed files
update_references() {
  local old_name="$1"
  local new_name="$2"
  local escaped_old=$(echo "$old_name" | sed 's/[\/&]/\\&/g')
  local escaped_new=$(echo "$new_name" | sed 's/[\/&]/\\&/g')
  local affected_files=""
  
  # Find files containing references to the old name
  grep -l -r --include="*.*" "$escaped_old" . 2>/dev/null | while read -r file; do
    # Skip binary files
    if file "$file" | grep -q "binary"; then
      continue
    fi
    
    # Skip the RENAME_LOG.md file itself
    if [[ "$file" == *"$RENAME_LOG"* ]]; then
      continue
    fi
    
    # Update references
    sed -i "s/$escaped_old/$escaped_new/g" "$file"
    echo "Updated references in $file"
    affected_files="$affected_files $file"
  done
  
  # Special handling for Python imports if the file is a Python file
  if [[ "$old_name" == *.py ]]; then
    # Extract module name without extension
    local old_module=$(basename "$old_name" .py)
    local new_module=$(basename "$new_name" .py)
    
    if [ "$old_module" != "$new_module" ]; then
      local escaped_old_module=$(echo "$old_module" | sed 's/[\/&]/\\&/g')
      local escaped_new_module=$(echo "$new_module" | sed 's/[\/&]/\\&/g')
      
      # Find Python files with import statements referencing the old module
      grep -l -r --include="*.py" "import.*$escaped_old_module\|from.*$escaped_old_module" . 2>/dev/null | while read -r pyfile; do
        # Skip the RENAME_LOG.md file itself
        if [[ "$pyfile" == *"$RENAME_LOG"* ]]; then
          continue
        fi
        
        # Update import statements
        sed -i "s/import $escaped_old_module/import $escaped_new_module/g" "$pyfile"
        sed -i "s/from $escaped_old_module/from $escaped_new_module/g" "$pyfile"
        sed -i "s/import $escaped_old_module as/import $escaped_new_module as/g" "$pyfile"
        echo "Updated Python imports in $pyfile"
        affected_files="$affected_files $pyfile"
      done
    fi
  fi
  
  # Special handling for JavaScript/TypeScript imports
  if [[ "$old_name" == *.js || "$old_name" == *.ts || "$old_name" == *.jsx || "$old_name" == *.tsx ]]; then
    # Extract module name without extension
    local old_module=$(basename "$old_name" | sed 's/\.[^.]*$//')
    local new_module=$(basename "$new_name" | sed 's/\.[^.]*$//')
    
    if [ "$old_module" != "$new_module" ]; then
      local escaped_old_module=$(echo "$old_module" | sed 's/[\/&]/\\&/g')
      local escaped_new_module=$(echo "$new_module" | sed 's/[\/&]/\\&/g')
      
      # Find JS/TS files with import statements referencing the old module
      grep -l -r --include="*.js" --include="*.ts" --include="*.jsx" --include="*.tsx" "import.*$escaped_old_module\|require.*$escaped_old_module" . 2>/dev/null | while read -r jsfile; do
        # Skip the RENAME_LOG.md file itself
        if [[ "$jsfile" == *"$RENAME_LOG"* ]]; then
          continue
        fi
        
        # Update import statements - more specific patterns
        sed -i "s/import.*from ['\"].*\/$escaped_old_module['\"].*\|import.*from ['\"]$escaped_old_module['\"].*\|import ['\"].*\/$escaped_old_module['\"].*\|import ['\"]$escaped_old_module['\"].*/import from '\/$escaped_new_module'/g" "$jsfile"
        sed -i "s/require(['\"].*\/$escaped_old_module['\"])\|require(['\"]$escaped_old_module['\"])/require('\/$escaped_new_module')/g" "$jsfile"
        echo "Updated JS/TS imports in $jsfile"
        affected_files="$affected_files $jsfile"
      done
    fi
  fi
  
  # Special handling for configuration files
  grep -l -r --include="*.json" --include="*.yaml" --include="*.yml" --include="*.xml" --include="*.toml" "$escaped_old" . 2>/dev/null | while read -r configfile; do
    # Skip the RENAME_LOG.md file itself
    if [[ "$configfile" == *"$RENAME_LOG"* ]]; then
      continue
    fi
    
    # Update path references
    sed -i "s/$escaped_old/$escaped_new/g" "$configfile"
    echo "Updated config references in $configfile"
    affected_files="$affected_files $configfile"
  done
  
  echo "$affected_files"
}

# Process files and directories
find . -type f -o -type d | grep -v "\.git" | sort -r | while read -r item; do
  # Skip if it's the .git directory or the RENAME_LOG.md file
  if [[ "$item" == *"/.git"* ]] || [[ "$item" == *"$RENAME_LOG"* ]]; then
    continue
  fi
  
  # Get the basename of the item
  basename=$(basename "$item")
  dirname=$(dirname "$item")
  
  # Skip if the basename is already standardized
  new_basename=$(standardize_name "$basename")
  if [ "$basename" != "$new_basename" ]; then
    old_path="$item"
    new_path="$dirname/$new_basename"
    
    # Find references before renaming
    affected_files=$(find_references "$basename")
    
    # Rename the item
    if [ -e "$new_path" ]; then
      echo "Warning: Cannot rename $old_path to $new_path - destination already exists"
    else
      mv "$old_path" "$new_path"
      echo "Renamed: $old_path -> $new_path"
      
      # Update references
      affected_files=$(update_references "$basename" "$new_basename")
      
      # Log the rename
      echo "| \`$old_path\` | \`$new_path\` | $(echo "$affected_files" | tr '\n' ' ' | sed 's/ /, /g') | References updated via sed | " >> "$RENAME_LOG"
    fi
  fi
done

echo "Standardization complete. See $RENAME_LOG for details."
