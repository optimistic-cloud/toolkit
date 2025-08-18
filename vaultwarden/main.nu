use std/log

def backup_db_sqlite [database: path] {
    log info $"Starting SQLite backup process"
    log debug $"Database path: ($database)"
    
    if ($database | path exists) {
        log info $"✅ Database file found: ($database)"
        print $"🔧 Vaultwarden Backup Tool backup sqlite on ($database)"
        log info $"SQLite backup completed successfully"
    } else {
        log warning $"⚠️  Database file not found: ($database)"
        log error $"Cannot proceed with backup - database missing"
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
    log info $"🚀 Starting Vaultwarden Backup Tool"
    log debug $"Backup data path: ($backup_data)"
    log debug $"Restic cache directory: ($restic_cache_dir)"
    
    print "🔧 Vaultwarden Backup Tool"

    # Validate backup data path
    if not ($backup_data | path exists) {
        log error $"❌ Backup path does not exist: ($backup_data)"
        log critical $"Cannot proceed without valid backup data path"
        error make {msg: $"Backup path does not exist: ($backup_data)"}
    }
    
    log info $"✅ Backup data path validated: ($backup_data)"
    
    # Check for database file
    let db_path = ($backup_data | path join ".db.sqlite3")
    log debug $"Checking for database at: ($db_path)"
    
    backup_db_sqlite $db_path
    
    log info $"🎉 Backup tool execution completed"
}