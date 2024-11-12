# Define the base directory for the project
$baseDir = "C:\Users\wesle\OneDrive - NU GUI\Documents\Python_Projects\VIZ_Script\database_migration_project"

# Define directories to create
$directories = @(
    $baseDir,
    "$baseDir\utils"
)

# Define files to create with initial comments
$files = @{
    "$baseDir\config.py"               = "# Configuration and environment management"
    "$baseDir\database_connections.py"  = "# DB connection handling and schema management"
    "$baseDir\migration_operations.py"  = "# Core migration logic and data processing"
    "$baseDir\user_interaction.py"      = "# User prompts and input handling"
    "$baseDir\error_handling.py"        = "# Error detection and dynamic fixes"
    "$baseDir\notifications.py"         = "# Email notification functions"
    "$baseDir\multi_threading.py"       = "# Multi-threaded migration execution"
    "$baseDir\main.py"                  = "# Main script entry and menu handling"
    "$baseDir\utils\constants.py"       = "# Constants for data types, schemas, etc."
    "$baseDir\utils\helpers.py"         = "# Helper functions for formatting, data parsing, etc."
}

# Create directories
foreach ($dir in $directories) {
    if (-Not (Test-Path -Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force
        Write-Host "Created directory: $dir"
    }
}

# Create files with initial comments
foreach ($file in $files.Keys) {
    if (-Not (Test-Path -Path $file)) {
        New-Item -ItemType File -Path $file -Force | Out-Null
        Set-Content -Path $file -Value $files[$file]
        Write-Host "Created file: $file"
    }
}

Write-Host "Project structure created successfully at $baseDir"
