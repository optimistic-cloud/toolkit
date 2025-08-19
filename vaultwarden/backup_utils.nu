use std/log

export-env {
    $env.HC_PING_WARNING_SHOWN = false
}

# Send healthcheck ping to monitoring service
export def hc_ping [endpoint: string] {
    if ($env.HC_PING_KEY? | is-empty) {
        if not $env.HC_PING_WARNING_SHOWN {
            log warning "HC_PING_KEY environment variable is not set, skipping all healthcheck calls"
            $env.HC_PING_WARNING_SHOWN = true
        }
        return
    }
    
    let url = $"https://hc-ping.com/($env.HC_PING_KEY)"
    let full_url = if ($endpoint == "") { $url } else { $"($url)/($endpoint)" }
    let timeout = 10sec
    
    try {
        http get $full_url --max-time $timeout | ignore
        log info $"Successfully called healthcheck endpoint: ($full_url)"
    } catch {|err|
        log warning $"Failed to send healthcheck ping: ($err.msg)"
        # Don't fail the entire backup for healthcheck failures
    }
}

# Create SQLite backup and compressed archive
export def create_backup_archive [] {
    log info "Creating database backup..."
    
    try {
        ^sqlite3 "/vaultwarden/data/db.sqlite3" ".backup '/vaultwarden/data/db-export.sqlite3'"
        log info "Database backup completed"
    } catch {|err|
        log error $"Database backup failed: ($err.msg)"
        error make {msg: "Database backup failed"}
    }
    
    try {
        log info "Creating compressed archive..."
        ^tar -cf - /vaultwarden/data | ^zstd -3q --rsyncable -o /vaultwarden/data/data.tar.zst
        log info "Archive creation completed"
    } catch {|err|
        log error $"Archive creation failed: ($err.msg)"
        error make {msg: "Archive creation failed"}
    }
    
    # Verify backup files were created
    if not ("/vaultwarden/data/db-export.sqlite3" | path exists) {
        log error "Database backup file not found after creation"
        error make {msg: "Database backup file not found"}
    }
    
    if not ("/vaultwarden/data/data.tar.zst" | path exists) {
        log error "Archive file not found after creation"
        error make {msg: "Archive file not found"}
    }
    
    log info "All backup files created successfully"
}

# Run restic backup operations for current repository
export def run_restic [] {
    let hostname = ($env.HOSTNAME? | default (sys host | get hostname))
    let tags = ($env.restic_tags? | default "vaultwarden")
    
    log info "Starting restic backup operations"
    
    try {
        log info "Running restic backup..."
        ^restic backup --host $hostname --tag $tags /vaultwarden/data --quiet
        log info "Restic backup completed"
        
        log info "Cleaning up old snapshots..."
        ^restic forget --keep-within "180d" --prune --quiet
        log info "Snapshot cleanup completed"
        
        log info "Verifying backup integrity..."
        ^restic check --read-data-subset "100%" --quiet
        log info "Backup verification completed"
        
    } catch {|err|
        log error $"Restic operation failed: ($err.msg)"
        error make {msg: $"Restic operation failed: ($err.msg)"}
    }
}

# Get list of restic repository directories
export def get_restic_repos [repo_base_dir: string = "/vaultwarden/restic-repos"] {
    if not ($repo_base_dir | path exists) {
        log warning $"Repository base directory does not exist: ($repo_base_dir)"
        return []
    }
    
    let repos = (ls $repo_base_dir | where type == dir | get name)
    log info $"Found (($repos | length)) restic repositories in ($repo_base_dir)"
    
    return $repos
}

# Validate repository configuration
export def validate_repo_config [repo_path: string] {
    let password_file = ($repo_path | path join "password")
    
    if not ($password_file | path exists) {
        log warning $"Password file not found for repository: ($password_file)"
        return false
    }
    
    # Could add more validation here (check restic repo accessibility, etc.)
    return true
}
