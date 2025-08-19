use std/log




# Create SQLite backup and compressed archive
export def create_backup_archive [] {
    log info "Creating database backup..."
    
    use backup_paths.nu *
    
    # Load configuration
    let config = try { 
        open config.yml 
    } catch { 
        {backup: {backup_dir: "auto", include_hostname: true, timestamp_format: "%Y%m%d_%H%M%S", database: {backup_filename: "vaultwarden_db"}, archive: {filename: "vaultwarden_data"}}}
    }
    
    # Get backup settings from config
    let backup_config = ($config.backup? | default {})
    let backup_dir = ($backup_config.backup_dir? | default "auto")
    let include_hostname = ($backup_config.include_hostname? | default true)
    let timestamp_format = ($backup_config.timestamp_format? | default "%Y%m%d_%H%M%S")
    let db_filename = ($backup_config.database?.backup_filename? | default "vaultwarden_db")
    let archive_filename = ($backup_config.archive?.filename? | default "vaultwarden_data")
    
    # Get optimal backup paths for this environment
    let db_backup_path = (get_backup_file_path $db_filename 
        --extension "sqlite3" 
        --include-hostname=$include_hostname
        --config-backup-dir $backup_dir
        --timestamp-format $timestamp_format)
    let archive_backup_path = (get_backup_file_path $archive_filename 
        --extension "tar.zst"
        --include-hostname=$include_hostname  
        --config-backup-dir $backup_dir
        --timestamp-format $timestamp_format)
    
    try {
        # Ensure backup directory exists
        let backup_dir = ($db_backup_path | path dirname)
        mkdir $backup_dir
        
        ^sqlite3 "/vaultwarden/data/db.sqlite3" $".backup '($db_backup_path)'"
        log info $"Database backup completed: ($db_backup_path)"
        
        # Verify database backup
        if not ($db_backup_path | path exists) {
            error make {msg: "Database backup file was not created"}
        }
        
        let db_size = (ls $db_backup_path | get size | first)
        if ($db_size | into int) == 0 {
            error make {msg: "Database backup file is empty"}
        }
        
    } catch {|err|
        log error $"Database backup failed: ($err.msg)"
        error make {msg: "Database backup failed"}
    }
    
    try {
        log info "Creating compressed archive..."
        ^tar -cf - /vaultwarden/data | ^zstd -3q --rsyncable -o $archive_backup_path
        log info $"Archive creation completed: ($archive_backup_path)"
        
        # Verify archive backup
        if not ($archive_backup_path | path exists) {
            error make {msg: "Archive backup file was not created"}
        }
        
        let archive_size = (ls $archive_backup_path | get size | first)
        if ($archive_size | into int) == 0 {
            error make {msg: "Archive backup file is empty"}
        }
        
        log info $"Backup verification completed - DB: ($db_size), Archive: ($archive_size)"
        
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
