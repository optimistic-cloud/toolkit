data_dir := "/vaultwarden/data"
restore_dir := "/vaultwarden/restore"
restic_cache_dir := "/vaultwarden/restic-cache"

# Show all available commands with descriptions
help:
	@just --list

# Execute Vaultwarden backup operation with error handling
backup:
    #!/usr/bin/env bash
    set -euo pipefail
    
    cleanup() {
        curl -fsS -m 10 --retry 2 -o /dev/null "https://hc-ping.com/vaultwarden/fail" || true
        exit 1
    }
    
    trap cleanup ERR INT TERM
    
    curl -fsS -m 10 --retry 5 -o /dev/null "https://hc-ping.com/vaultwarden/start"
    
    sqlite3 "/vaultwarden/data/db.sqlite3" ".backup '/vaultwarden/data/db-export.sqlite3'"
    
		tar -cf - /path/to/your/data | zstd -3q --rsyncable | restic backup --stdin --stdin-filename data.tar.zst -r /path/to/restic/repo


    restic backup /vaultwarden/data --host "${HOSTNAME:-localhost}" --tag "${restic_tags:-vaultwarden}" --quiet
    restic forget --keep-within 180d --prune --quiet
    restic check --read-data-subset 100% --quiet
    
    curl -fsS -m 10 --retry 5 -o /dev/null "https://hc-ping.com/vaultwarden"
    
    trap - ERR INT TERM
    
# Execute Vaultwarden restore operation with comprehensive error handling
restore snapshot_id:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Global variables for cleanup
    TEMP_DIR=""
    LOCK_FILE="/tmp/vaultwarden-restore.lock"
    
    # Comprehensive cleanup function
    cleanup() {
        local exit_code=$?
        echo "🧹 Performing cleanup (exit code: $exit_code)..."
        
        # Remove lock file
        [[ -f "$LOCK_FILE" ]] && rm -f "$LOCK_FILE"
        
        # Clean up temporary directory
        [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
        
        # Send appropriate notification based on exit code
        if [[ $exit_code -eq 0 ]]; then
            echo "✅ Restore completed successfully"
        else
            echo "❌ Restore failed with exit code: $exit_code"
            curl -fsS -m 10 --retry 2 -o /dev/null "https://hc-ping.com/{{uuid}}/fail" || true
        fi
        
        exit $exit_code
    }
    
    # Set up comprehensive trap
    trap cleanup EXIT
    trap 'echo "🛑 Received interrupt signal"; exit 130' INT
    trap 'echo "🛑 Received termination signal"; exit 143' TERM
    trap 'echo "❌ Error occurred on line $LINENO"; exit 1' ERR
    
    # Check if another restore is running
    if [[ -f "$LOCK_FILE" ]]; then
        echo "❌ Another restore operation is already running"
        exit 1
    fi
    
    # Create lock file
    echo $$ > "$LOCK_FILE"
    
    echo "🔧 Starting Vaultwarden restore for snapshot: {{snapshot_id}}"
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d "/tmp/vaultwarden-restore.XXXXXX")
    echo "📁 Using temporary directory: $TEMP_DIR"
    
    # Run the actual restore
    nu main.nu restore --snapshot-id {{snapshot_id}} --restore-dir {{restore_dir}}
    
    echo "🎉 Restore operation completed!"

# Example: Simple trap for basic error handling
simple-backup:
    #!/usr/bin/env bash
    set -e  # Exit on any error
    
    # Simple error handler
    trap 'echo "❌ Backup failed at line $LINENO"; exit 1' ERR
    trap 'echo "🛑 Backup interrupted"; exit 130' INT
    
    echo "📋 Simple backup starting..."
    cp "/vaultwarden/data/db.sqlite3" "/backup/db-$(date +%Y%m%d).sqlite3"
    echo "✅ Simple backup completed"

# Example: Advanced trap with logging
advanced-backup:
    #!/usr/bin/env bash
    set -euo pipefail
    
    LOG_FILE="/var/log/vaultwarden-backup.log"
    
    # Advanced error handler with logging
    error_handler() {
        local line_number=$1
        local error_code=$2
        local command="$3"
        
        {
            echo "=================================="
            echo "ERROR OCCURRED: $(date)"
            echo "Line: $line_number"
            echo "Exit code: $error_code" 
            echo "Command: $command"
            echo "=================================="
        } >> "$LOG_FILE"
        
        echo "❌ Error on line $line_number (exit $error_code): $command"
        echo "📝 Details logged to: $LOG_FILE"
        exit $error_code
    }
    
    # Set up advanced trap
    trap 'error_handler $LINENO $? "$BASH_COMMAND"' ERR
    
    echo "🔧 Advanced backup with logging..."
    # Your backup commands here
    echo "✅ Advanced backup completed"