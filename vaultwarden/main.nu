use std/log

def backup_db_sqlite [database: path, export_dir: path] {
    log info "Starting SQLite backup process"
    log debug $"Database path: ($database)"
    log debug $"Export directory: ($export_dir)"
    
    if not ($database | path exists) {
        error make {success: false, error: "Database file does not exist"}
    }
    
    if not ($export_dir | path exists) {
        log warning $"⚠️  Export directory does not exist, creating: ($export_dir)"
        try {
            mkdir ($export_dir)
            log info $"📁 Created export directory: ($export_dir)"
        } catch {|err|
            log error $"❌ Failed to create export directory: ($err.msg)"
            error make {success: false, error: $"Cannot create export directory: ($err.msg)"}
        }
    }
    
    # Generate backup filename with timestamp
    let timestamp = (date now | format date "%Y%m%d_%H%M%S")
    let backup_filename = $"vaultwarden_backup_($timestamp).sqlite3"
    let backup_path = ($export_dir | path join $backup_filename)
    
    log info $"✅ Starting SQLite backup to: ($backup_path)"
    
    try {
        ^sqlite3 $database $".backup '($backup_path)'"
        
        # Verify the backup file was created and has content
        if ($backup_path | path exists) {
            let backup_size = (ls $backup_path | get size | first)
            if $backup_size > 0 {
                log info $"🎉 SQLite backup completed successfully"
                log info $"📊 Backup file size: ($backup_size)"
                log info $"📁 Backup location: ($backup_path)"
                return {
                    success: true, 
                    backup_path: $backup_path, 
                    size: $backup_size,
                    timestamp: $timestamp
                }
            } else {
                log error $"❌ Backup file created but is empty: ($backup_path)"
                return {success: false, error: "Backup file is empty"}
            }
        } else {
            log error $"❌ Backup file was not created: ($backup_path)"
            return {success: false, error: "Backup file not created"}
        }
    } catch {|err|
        log error $"❌ SQLite backup failed: ($err.msg)"
        return {success: false, error: $err.msg}
    }
}

def "main restore" [--snapshot-id: number --restore-dir: path] {
    log info $"🔧 Starting Vaultwarden restore operation"
    log info $"Snapshot ID: ($snapshot_id)"
    log info $"Restore directory: ($restore_dir)"
    
    # Log the operation details
    log debug $"Restore parameters - snapshot: ($snapshot_id), target: ($restore_dir)"
    
    if ($restore_dir | path exists) {
        log info $"✅ Restore directory exists: ($restore_dir)"
    } else {
        log warning $"⚠️  Restore directory does not exist, will create: ($restore_dir)"
        try {
            mkdir ($restore_dir)
            log info $"📁 Created restore directory: ($restore_dir)"
        } catch {
            log error $"❌ Failed to create restore directory: ($restore_dir)"
            error make {msg: $"Cannot create restore directory: ($restore_dir)"}
        }
    }
}

def main [--backup-data: path --restic-cache-dir: path] {
    log info "🚀 Starting Vaultwarden Backup Tool"
    log debug $"Backup data path: ($backup_data)"
    log debug $"Restic cache directory: ($restic_cache_dir)"
    
    print "🔧 Vaultwarden Backup Tool"

    # Validate backup data path
    if not ($backup_data | path exists) {
        log error $"❌ Backup path does not exist: ($backup_data)"
        log critical "Cannot proceed without valid backup data path"
        error make {msg: $"Backup path does not exist: ($backup_data)"}
    }
    
    log info $"✅ Backup data path validated: ($backup_data)"
    
    # Check for database file
    let db_path = ($backup_data | path join "db.sqlite3")
    log debug $"Checking for database at: ($db_path)"
    
    # Create backup export directory
    let export_dir = ($restic_cache_dir | default "/tmp/backup" | path join "exports")
    log debug $"Export directory: ($export_dir)"
    
    # Perform SQLite backup
    let backup_result = (backup_db_sqlite $db_path $export_dir)
    
    if $backup_result.success {
        log info $"🎉 Backup completed successfully!"
        log info $"📁 Backup file: ($backup_result.backup_path)"
        log info $"📊 File size: ($backup_result.size)"
    } else {
        log error $"❌ Backup failed: ($backup_result.error)"
        error make {msg: $"Backup operation failed: ($backup_result.error)"}
    }
    
    log info "🎉 Backup tool execution completed"
}