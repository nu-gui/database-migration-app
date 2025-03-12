#!/bin/bash

# Script to fix references in repositories that have already been processed
# Usage: ./fix_references.sh /path/to/repository

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_PATH="${1:-$(pwd)}"
RENAME_LOG="RENAME_LOG.md"

cd "$REPO_PATH"

echo "Fixing references in $REPO_PATH..."

# Check if RENAME_LOG.md exists
if [ ! -f "$RENAME_LOG" ]; then
  echo "Error: $RENAME_LOG not found in $REPO_PATH"
  exit 1
fi

# Extract renamed files from RENAME_LOG.md
echo "Extracting renamed files from $RENAME_LOG..."
grep -E "^\| \`.*\` \| \`.*\` \|" "$RENAME_LOG" | while read -r line; do
  old_path=$(echo "$line" | sed -E 's/^\| `(.*)` \| `.*` \|.*$/\1/')
  new_path=$(echo "$line" | sed -E 's/^\| `.*` \| `(.*)` \|.*$/\1/')
  
  if [ -n "$old_path" ] && [ -n "$new_path" ]; then
    echo "Processing rename: $old_path -> $new_path"
    
    # Get the basename of the files
    old_basename=$(basename "$old_path")
    new_basename=$(basename "$new_path")
    
    # Update Python imports if it's a Python file
    if [[ "$old_basename" == *.py ]]; then
      old_module=$(basename "$old_basename" .py)
      new_module=$(basename "$new_basename" .py)
      
      if [ "$old_module" != "$new_module" ]; then
        echo "Updating Python imports: $old_module -> $new_module"
        grep -l -r --include="*.py" "import.*$old_module\|from.*$old_module" . 2>/dev/null | while read -r pyfile; do
          sed -i "s/import $old_module/import $new_module/g" "$pyfile"
          sed -i "s/from $old_module/from $new_module/g" "$pyfile"
          sed -i "s/import $old_module as/import $new_module as/g" "$pyfile"
          echo "  Updated Python imports in $pyfile"
        done
      fi
    fi
    
    # Update JavaScript/TypeScript imports if it's a JS/TS file
    if [[ "$old_basename" == *.js || "$old_basename" == *.ts || "$old_basename" == *.jsx || "$old_basename" == *.tsx ]]; then
      old_module=$(basename "$old_basename" | sed 's/\.[^.]*$//')
      new_module=$(basename "$new_basename" | sed 's/\.[^.]*$//')
      
      if [ "$old_module" != "$new_module" ]; then
        echo "Updating JS/TS imports: $old_module -> $new_module"
        grep -l -r --include="*.js" --include="*.ts" --include="*.jsx" --include="*.tsx" "import.*$old_module\|require.*$old_module" . 2>/dev/null | while read -r jsfile; do
          sed -i "s/import.*from ['\"].*\/$old_module['\"].*/import from '\/$new_module'/g" "$jsfile"
          sed -i "s/require(['\"].*\/$old_module['\"])/require('\/$new_module')/g" "$jsfile"
          echo "  Updated JS/TS imports in $jsfile"
        done
      fi
    fi
    
    # Update configuration file references
    echo "Updating config references: $old_basename -> $new_basename"
    grep -l -r --include="*.json" --include="*.yaml" --include="*.yml" --include="*.xml" --include="*.toml" "$old_basename" . 2>/dev/null | while read -r configfile; do
      sed -i "s/$old_basename/$new_basename/g" "$configfile"
      echo "  Updated config references in $configfile"
    done
  fi
done

echo "Reference fixing complete in $REPO_PATH"
