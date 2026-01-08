#!/bin/bash

################################################################################
# VPS Auto Restore Script
# 
# This script automates the restoration of VPS backups
# Features:
# - Automatic backup detection and restoration
# - Service management (stop/start)
# - Data integrity validation
# - Comprehensive logging
# - Error handling and cleanup
#
# Usage: ./restore.sh [BACKUP_DATE]
# Example: ./restore.sh 2024-01-15
################################################################################

set -euo pipefail

# Configuration
BACKUP_DIR="${BACKUP_DIR:-.}"
RESTORE_DIR="${RESTORE_DIR:-.}"
LOG_DIR="${LOG_DIR:-.logs}"
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S")
LOG_FILE="${LOG_DIR}/restore_${TIMESTAMP// /_}.log"

# Backup items to restore
BACKUP_ITEMS=(
    "home"
    "etc"
    "var"
)

# Services to stop during restore
SERVICES_TO_STOP=(
    "nginx"
    "mysql"
    "php-fpm"
)

################################################################################
# Logging Functions
################################################################################

# Initialize log directory
mkdir -p "${LOG_DIR}"

log_info() {
    local message="$1"
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S')] [INFO] $message" | tee -a "${LOG_FILE}"
}

log_error() {
    local message="$1"
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S')] [ERROR] $message" | tee -a "${LOG_FILE}" >&2
}

log_warn() {
    local message="$1"
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S')] [WARN] $message" | tee -a "${LOG_FILE}"
}

################################################################################
# Validation Functions
################################################################################

# Validate BACKUP_ITEMS array
validate_backup_items() {
    log_info "Validating backup items configuration..."
    
    if [[ ${#BACKUP_ITEMS[@]} -eq 0 ]]; then
        log_error "BACKUP_ITEMS array is empty. No items to restore."
        return 1
    fi
    
    for item in "${BACKUP_ITEMS[@]}"; do
        if [[ -z "$item" ]]; then
            log_error "Found empty item in BACKUP_ITEMS array."
            return 1
        fi
    done
    
    log_info "Backup items validation passed. Items: ${BACKUP_ITEMS[*]}"
    return 0
}

# Validate backup directory exists
validate_backup_dir() {
    log_info "Validating backup directory..."
    
    if [[ ! -d "${BACKUP_DIR}" ]]; then
        log_error "Backup directory does not exist: ${BACKUP_DIR}"
        return 1
    fi
    
    log_info "Backup directory validated: ${BACKUP_DIR}"
    return 0
}

# Validate tar archive content
validate_tar_content() {
    local tarfile="$1"
    
    log_info "Validating tar archive content: ${tarfile}"
    
    if [[ ! -f "${tarfile}" ]]; then
        log_error "Tar file not found: ${tarfile}"
        return 1
    fi
    
    # Test tar file integrity
    if ! tar -tzf "${tarfile}" > /dev/null 2>&1; then
        log_error "Tar file is corrupted or invalid: ${tarfile}"
        return 1
    fi
    
    # Check if tar file contains expected items
    local expected_count=${#BACKUP_ITEMS[@]}
    local found_count=0
    
    for item in "${BACKUP_ITEMS[@]}"; do
        if tar -tzf "${tarfile}" | grep -q "^${item}/" || tar -tzf "${tarfile}" | grep -q "^${item}$"; then
            ((found_count++))
            log_info "Found expected item in archive: ${item}"
        else
            log_warn "Expected item not found in archive: ${item}"
        fi
    done
    
    if [[ ${found_count} -eq 0 ]]; then
        log_error "No expected backup items found in tar archive"
        return 1
    fi
    
    log_info "Tar archive validation passed (found ${found_count}/${expected_count} expected items)"
    return 0
}

################################################################################
# Service Management Functions
################################################################################

# Stop services gracefully
stop_services() {
    log_info "Stopping services..."
    
    for service in "${SERVICES_TO_STOP[@]}"; do
        if systemctl is-active --quiet "${service}" 2>/dev/null; then
            log_info "Stopping service: ${service}"
            if systemctl stop "${service}" 2>/dev/null; then
                log_info "Successfully stopped service: ${service}"
            else
                log_error "Failed to stop service: ${service}. Continuing anyway."
            fi
        else
            log_info "Service is not running or does not exist: ${service}"
        fi
    done
    
    log_info "Service stop operations completed"
}

# Start services
start_services() {
    log_info "Starting services..."
    
    for service in "${SERVICES_TO_STOP[@]}"; do
        if systemctl is-enabled --quiet "${service}" 2>/dev/null; then
            log_info "Starting service: ${service}"
            if systemctl start "${service}" 2>/dev/null; then
                log_info "Successfully started service: ${service}"
            else
                log_error "Failed to start service: ${service}"
            fi
        fi
    done
    
    log_info "Service start operations completed"
}

################################################################################
# Backup Selection Functions
################################################################################

# Find latest backup if no date specified
find_latest_backup() {
    log_info "Finding latest backup..."
    
    # Sort backups by date using -V flag for version sort (handles dates correctly)
    local latest_backup=$(find "${BACKUP_DIR}" -maxdepth 1 -name "*.tar.gz" -type f | \
                         sort -V | tail -1)
    
    if [[ -z "${latest_backup}" ]]; then
        log_error "No backup files found in ${BACKUP_DIR}"
        return 1
    fi
    
    log_info "Latest backup found: ${latest_backup}"
    echo "${latest_backup}"
    return 0
}

# Find backup by date
find_backup_by_date() {
    local backup_date="$1"
    log_info "Searching for backup from date: ${backup_date}"
    
    # Search for backup matching the date pattern
    local backups=$(find "${BACKUP_DIR}" -maxdepth 1 -name "*${backup_date}*.tar.gz" -type f)
    
    if [[ -z "${backups}" ]]; then
        log_error "No backup found for date: ${backup_date}"
        return 1
    fi
    
    # If multiple backups found, get the latest one
    local latest_backup=$(echo "${backups}" | sort -V | tail -1)
    
    log_info "Backup found for date ${backup_date}: ${latest_backup}"
    echo "${latest_backup}"
    return 0
}

################################################################################
# Restore Functions
################################################################################

# Extract backup
extract_backup() {
    local tarfile="$1"
    
    log_info "Extracting backup from: ${tarfile}"
    
    if [[ ! -f "${tarfile}" ]]; then
        log_error "Backup file not found: ${tarfile}"
        return 1
    fi
    
    if ! tar -xzf "${tarfile}" -C "${RESTORE_DIR}"; then
        log_error "Failed to extract backup: ${tarfile}"
        return 1
    fi
    
    log_info "Backup extracted successfully to: ${RESTORE_DIR}"
    return 0
}

# Cleanup tarball after successful restore
cleanup_tarball() {
    local tarfile="$1"
    
    if [[ -z "${tarfile}" ]] || [[ ! -f "${tarfile}" ]]; then
        log_warn "Tarball cleanup requested but file not found: ${tarfile}"
        return 0
    fi
    
    log_info "Cleaning up temporary tarball: ${tarfile}"
    
    if rm -f "${tarfile}"; then
        log_info "Tarball cleaned up successfully"
        return 0
    else
        log_error "Failed to cleanup tarball: ${tarfile}"
        return 1
    fi
}

################################################################################
# Main Restore Function
################################################################################

main() {
    log_info "=========================================="
    log_info "VPS Auto Restore Script Started"
    log_info "=========================================="
    
    # Validate configuration
    if ! validate_backup_items; then
        log_error "Backup items validation failed"
        exit 1
    fi
    
    if ! validate_backup_dir; then
        log_error "Backup directory validation failed"
        exit 1
    fi
    
    # Find backup to restore
    local backup_file=""
    if [[ $# -eq 1 ]]; then
        if ! backup_file=$(find_backup_by_date "$1"); then
            log_error "Failed to find backup for date: $1"
            exit 1
        fi
    else
        if ! backup_file=$(find_latest_backup); then
            log_error "Failed to find latest backup"
            exit 1
        fi
    fi
    
    # Validate tar content before proceeding
    if ! validate_tar_content "${backup_file}"; then
        log_error "Backup validation failed. Aborting restore operation."
        exit 1
    fi
    
    # Stop services
    stop_services
    
    # Extract backup
    if ! extract_backup "${backup_file}"; then
        log_error "Backup extraction failed. Attempting to restart services..."
        start_services
        exit 1
    fi
    
    # Start services
    start_services
    
    # Cleanup tarball
    if ! cleanup_tarball "${backup_file}"; then
        log_warn "Tarball cleanup failed, but restore completed successfully"
    fi
    
    log_info "=========================================="
    log_info "VPS Auto Restore Completed Successfully"
    log_info "=========================================="
    return 0
}

# Execute main function
main "$@"
