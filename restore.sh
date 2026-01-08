#!/bin/bash

# VPS Auto Restore Script
# This script restores backups from a backup server to a local VPS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKUP_SERVER="${BACKUP_SERVER:-backup.example.com}"
BACKUP_USER="${BACKUP_USER:-backupuser}"
BACKUP_PATH="${BACKUP_PATH:-/backups}"
BACKUP_ITEMS="${BACKUP_ITEMS:-}"
LOCAL_RESTORE_PATH="${LOCAL_RESTORE_PATH:-/restore}"
LOG_FILE="${LOG_FILE:-/var/log/vps-restore.log}"
TEMP_DIR="${TEMP_DIR:-/tmp/vps-restore}"

# Ensure log file is writable
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/vps-restore.log"

# Logging function
log() {
    local level="$1"
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[${timestamp}] [${level}] ${message}" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$@"
}

log_warn() {
    log "WARN" "$@"
}

log_error() {
    log "ERROR" "$@"
}

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $@"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $@"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $@"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $@"
}

# Cleanup function
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_error "Script exited with error code $exit_code"
    fi
    
    # Remove temporary directory
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        log_info "Cleaned up temporary directory: $TEMP_DIR"
    fi
    
    # Cleanup downloaded tarball
    if [ -n "$TARBALL_PATH" ] && [ -f "$TARBALL_PATH" ]; then
        rm -f "$TARBALL_PATH"
        log_info "Cleaned up downloaded tarball: $TARBALL_PATH"
    fi
    
    exit $exit_code
}

trap cleanup EXIT

# Validate BACKUP_ITEMS
validate_backup_items() {
    if [ -z "$BACKUP_ITEMS" ]; then
        log_error "BACKUP_ITEMS is not set or is empty. Please configure BACKUP_ITEMS environment variable."
        print_error "BACKUP_ITEMS must contain at least one backup item to restore."
        return 1
    fi
    
    log_info "BACKUP_ITEMS validation passed: $BACKUP_ITEMS"
    return 0
}

# Function to check if backup server is reachable
check_backup_server() {
    print_info "Checking backup server connectivity..."
    if ping -c 1 -W 2 "$BACKUP_SERVER" > /dev/null 2>&1; then
        print_success "Backup server is reachable"
        log_info "Backup server $BACKUP_SERVER is reachable"
        return 0
    else
        print_error "Backup server is not reachable"
        log_error "Failed to reach backup server: $BACKUP_SERVER"
        return 1
    fi
}

# Function to list available backups
list_backups() {
    print_info "Listing available backups..."
    log_info "Attempting to list backups from $BACKUP_SERVER:$BACKUP_PATH"
    
    # This is a placeholder - adjust based on your backup server setup
    # You might use scp, rsync, or other methods
    
    print_info "Available backups:"
    # ssh $BACKUP_USER@$BACKUP_SERVER "ls -lh $BACKUP_PATH" || {
    #     print_error "Failed to list backups"
    #     log_error "Failed to list backups from remote server"
    #     return 1
    # }
}

# Function to download backup
download_backup() {
    local backup_name="$1"
    
    if [ -z "$backup_name" ]; then
        print_error "No backup name provided"
        log_error "download_backup called without backup name"
        return 1
    fi
    
    print_info "Downloading backup: $backup_name"
    log_info "Starting download of backup: $backup_name"
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    
    local remote_file="$BACKUP_SERVER:$BACKUP_PATH/$backup_name"
    TARBALL_PATH="$TEMP_DIR/$backup_name"
    
    # Download the backup
    if scp "$BACKUP_USER@$remote_file" "$TARBALL_PATH" > /dev/null 2>&1; then
        print_success "Backup downloaded successfully"
        log_info "Backup downloaded to: $TARBALL_PATH"
        return 0
    else
        print_error "Failed to download backup"
        log_error "Failed to download backup from $remote_file to $TARBALL_PATH"
        return 1
    fi
}

# Function to validate tar content before extraction
validate_tar_content() {
    local tarball_path="$1"
    
    if [ -z "$tarball_path" ]; then
        log_error "No tarball path provided for validation"
        return 1
    fi
    
    if [ ! -f "$tarball_path" ]; then
        log_error "Tarball file not found: $tarball_path"
        return 1
    fi
    
    log_info "Validating tar content: $tarball_path"
    
    # Check if tar file is valid
    if ! tar -tzf "$tarball_path" > /dev/null 2>&1; then
        log_error "Tar file validation failed: $tarball_path is corrupted or invalid"
        print_error "Tar file is corrupted or invalid"
        return 1
    fi
    
    # List tar contents for logging
    log_info "Tar file contents:"
    tar -tzf "$tarball_path" | head -20 | while read -r line; do
        log_info "  - $line"
    done
    log_info "...and more files"
    
    print_success "Tar file validation passed"
    log_info "Tar file validation successful"
    return 0
}

# Function to extract backup
extract_backup() {
    local tarball_path="$1"
    local extract_path="$2"
    
    if [ -z "$tarball_path" ] || [ -z "$extract_path" ]; then
        print_error "Missing tarball path or extract path"
        log_error "extract_backup called with missing parameters"
        return 1
    fi
    
    # Validate tar content before extraction
    if ! validate_tar_content "$tarball_path"; then
        print_error "Tar content validation failed, aborting extraction"
        log_error "Aborting extraction due to tar validation failure"
        return 1
    fi
    
    print_info "Extracting backup to: $extract_path"
    log_info "Starting extraction of backup to: $extract_path"
    
    # Create extract directory
    mkdir -p "$extract_path"
    
    # Extract the backup
    if tar -xzf "$tarball_path" -C "$extract_path"; then
        print_success "Backup extracted successfully"
        log_info "Backup extraction completed successfully"
        return 0
    else
        print_error "Failed to extract backup"
        log_error "Failed to extract backup from $tarball_path to $extract_path"
        return 1
    fi
}

# Function to stop services
stop_services() {
    local services="$1"
    
    if [ -z "$services" ]; then
        log_warn "No services specified for stopping"
        return 0
    fi
    
    print_info "Stopping services..."
    log_info "Attempting to stop services: $services"
    
    for service in $services; do
        print_info "Stopping service: $service"
        log_info "Sending stop command to service: $service"
        
        if systemctl stop "$service" 2>&1; then
            print_success "Service stopped: $service"
            log_info "Service stopped successfully: $service"
        else
            local error_msg="Failed to stop service: $service"
            print_error "$error_msg"
            log_error "$error_msg - This may impact restore process"
            # Don't return 1 here as we want to continue with restoration
            # even if some services fail to stop
        fi
    done
    
    log_info "Service stop operations completed"
    return 0
}

# Function to restore files
restore_files() {
    local source_dir="$1"
    local target_dir="$2"
    
    if [ -z "$source_dir" ] || [ -z "$target_dir" ]; then
        print_error "Missing source or target directory"
        log_error "restore_files called with missing parameters"
        return 1
    fi
    
    if [ ! -d "$source_dir" ]; then
        print_error "Source directory not found: $source_dir"
        log_error "Source directory does not exist: $source_dir"
        return 1
    fi
    
    print_info "Restoring files from $source_dir to $target_dir"
    log_info "Starting file restore from: $source_dir to: $target_dir"
    
    # Create target directory if it doesn't exist
    mkdir -p "$target_dir"
    
    # Copy files with backup of existing files
    if cp -rp "$source_dir"/* "$target_dir/" 2>&1; then
        print_success "Files restored successfully"
        log_info "Files restored successfully to: $target_dir"
        return 0
    else
        print_error "Failed to restore files"
        log_error "Failed to restore files to: $target_dir"
        return 1
    fi
}

# Function to start services
start_services() {
    local services="$1"
    
    if [ -z "$services" ]; then
        log_warn "No services specified for starting"
        return 0
    fi
    
    print_info "Starting services..."
    log_info "Attempting to start services: $services"
    
    for service in $services; do
        print_info "Starting service: $service"
        log_info "Sending start command to service: $service"
        
        if systemctl start "$service" 2>&1; then
            print_success "Service started: $service"
            log_info "Service started successfully: $service"
        else
            local error_msg="Failed to start service: $service"
            print_error "$error_msg"
            log_error "$error_msg"
        fi
    done
    
    log_info "Service start operations completed"
    return 0
}

# Function to find latest backup
find_latest_backup() {
    local item="$1"
    
    if [ -z "$item" ]; then
        log_error "No backup item specified"
        return 1
    fi
    
    print_info "Finding latest backup for: $item"
    log_info "Searching for latest backup of: $item"
    
    # This is a placeholder function
    # Adjust based on your backup naming convention
    # The function should return the path to the latest backup
    
    # Example: sort backups by date and get the latest one
    # Note: Using -V flag for natural version sorting (date format)
    local latest_backup=$(ssh "$BACKUP_USER@$BACKUP_SERVER" "ls -1 $BACKUP_PATH/${item}_* 2>/dev/null | sort -V | tail -1")
    
    if [ -z "$latest_backup" ]; then
        print_error "No backups found for: $item"
        log_error "No backups found for item: $item"
        return 1
    fi
    
    print_info "Latest backup found: $latest_backup"
    log_info "Latest backup for $item: $latest_backup"
    echo "$latest_backup"
}

# Main restore function
main() {
    log_info "=========================================="
    log_info "VPS Auto Restore Script Started"
    log_info "=========================================="
    log_info "Backup Server: $BACKUP_SERVER"
    log_info "Backup Path: $BACKUP_PATH"
    log_info "Restore Path: $LOCAL_RESTORE_PATH"
    log_info "Temp Directory: $TEMP_DIR"
    
    print_info "VPS Auto Restore Script"
    print_info "======================="
    
    # Validate BACKUP_ITEMS
    if ! validate_backup_items; then
        print_error "Backup items validation failed"
        log_error "Script terminating due to validation failure"
        exit 1
    fi
    
    # Check backup server connectivity
    if ! check_backup_server; then
        print_error "Cannot reach backup server"
        log_error "Script terminating: backup server unreachable"
        exit 1
    fi
    
    # List available backups
    list_backups
    
    # Process each backup item
    for item in $BACKUP_ITEMS; do
        print_info "Processing backup item: $item"
        log_info "Starting processing of backup item: $item"
        
        # Find latest backup for this item
        backup_file=$(find_latest_backup "$item")
        if [ -z "$backup_file" ]; then
            print_warning "Skipping item $item: no backups found"
            log_warn "Skipped item $item due to no available backups"
            continue
        fi
        
        # Download backup
        if ! download_backup "$backup_file"; then
            print_warning "Failed to download backup for $item, continuing with next item"
            log_warn "Download failed for item $item, continuing"
            continue
        fi
        
        # Extract backup
        local extract_path="$LOCAL_RESTORE_PATH/$item"
        if ! extract_backup "$TARBALL_PATH" "$extract_path"; then
            print_warning "Failed to extract backup for $item"
            log_warn "Extraction failed for item $item"
            continue
        fi
        
        # Restore files
        if ! restore_files "$extract_path" "/$item"; then
            print_warning "Failed to restore files for $item"
            log_warn "File restoration failed for item $item"
            continue
        fi
        
        print_success "Item $item restored successfully"
        log_info "Item $item restore completed successfully"
    done
    
    print_success "Restore process completed"
    log_info "=========================================="
    log_info "VPS Auto Restore Script Completed"
    log_info "=========================================="
}

# Run main function
main "$@"
