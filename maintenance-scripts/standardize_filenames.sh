#!/bin/bash
# Script to standardize file and folder names in a repository
# Usage: ./standardize_filenames.sh /path/to/repository

set -e

REPO_PATH=$1
RENAME_LOG="RENAME_LOG.md"

if [ -z "$REPO_PATH" ]; then
  echo "Usage: $0 /path/to/repository"
  exit 1
fi

if [ ! -d "$REPO_PATH" ]; then
  echo "Error: $REPO_PATH is not a valid directory"
  exit 1
fi

cd "$REPO_PATH"

# Create or initialize RENAME_LOG.md
echo "# File and Folder Rename Log" > "$RENAME_LOG"
echo "" >> "$RENAME_LOG"
echo "This document tracks all file and folder renames performed during repository maintenance." >> "$RENAME_LOG"
echo "" >> "$RENAME_LOG"
echo "## Renamed Files and Folders" >> "$RENAME_LOG"
echo "" >> "$RENAME_LOG"
echo "| Old Name | New Name | Affected Files | Steps Taken |" >> "$RENAME_LOG"
echo "|----------|----------|----------------|-------------|" >> "$RENAME_LOG"

# Function to convert a filename to lowercase and replace spaces with underscores
standardize_name() {
  local old_name="$1"
  local new_name=$(echo "$old_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
  echo "$new_name"
}

# Function to find all references to a file or folder
find_references() {
  local old_name="$1"
  local escaped_name=$(echo "$old_name" | sed 's/[\/&]/\\&/g')
  grep -r --include="*.*" "$escaped_name" . 2>/dev/null || echo "No references found"
}

# Function to update references in files
update_references() {
  local old_name="$1"
  local new_name="$2"
  local escaped_old=$(echo "$old_name" | sed 's/[\/&]/\\&/g')
  local escaped_new=$(echo "$new_name" | sed 's/[\/&]/\\&/g')
  
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
  done
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
      update_references "$basename" "$new_basename"
      
      # Log the rename
      echo "| \`$old_path\` | \`$new_path\` | $(echo "$affected_files" | tr '\n' ' ' | sed 's/ /, /g') | References updated via sed | " >> "$RENAME_LOG"
    fi
  fi
done

echo "Standardization complete. See $RENAME_LOG for details."
