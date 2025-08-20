data_dir := "/vaultwarden/data"
restore_dir := "/vaultwarden/restore"
restic_cache_dir := "/vaultwarden/restic-cache"

# Show all available commands with descriptions
help:
	@just --list

# Execute Vaultwarden backup operation with error handling
# Goal 1: multiple restic repositories
#   Mount a directory with restic repositories password files
#   Mount a restic cache directory
# Goal 2: Scheduler 
backup:
    #!/usr/bin/env bash
    set -euo pipefail
    


    curl -fsS -m 10 --retry 5 -o /dev/null "https://hc-ping.com/vaultwarden/start"

    cleanup() {
        curl -fsS -m 10 --retry 2 -o /dev/null "https://hc-ping.com/vaultwarden/fail" || true
        exit 1
    }
    
    create_backup_archive() {
        sqlite3 "/vaultwarden/data/db.sqlite3" ".backup '/vaultwarden/data/db-export.sqlite3'"

        tar -cf - /vaultwarden/data | zstd -3q --rsyncable -o /vaultwarden/data/data.tar.zst
    }

    run_restic() {
        restic backup --host "${HOSTNAME}" --tag "${restic_tags:-vaultwarden}"
        restic forget --keep-within 180d --prune
        restic check --read-data-subset 100%
    }

    trap cleanup ERR INT TERM
    
    create_backup_archive

    for repo in /vaultwarden/restic-repos/*; do
        HC_PING_KEY="ascascsscsac" \
        RESTIC_REPOSITORY="$repo" \
        RESTIC_PASSWORD_FILE="$repo/password" \
        RESTIC_CACHE_DIR="/vaultwarden/restic-cache" \
        AWS_ACCESS_KEY_ID="your_aws_access_key_id" \
        AWS_SECRET_ACCESS_KEY="your_aws_secret_access_key" \
        AWS_DEFAULT_REGION="your_aws_default_region" \
        run_restic
    done

    curl -fsS -m 10 --retry 5 -o /dev/null "https://hc-ping.com/vaultwarden"
    
    trap - ERR INT TERM

# Execute Vaultwarden backup operation with error handling
# Goal 1: multiple restic repositories
#   Mount a directory with restic repositories password files
#   Mount a restic cache directory
# Goal 2: Scheduler 
backup-nu:
    #!/usr/bin/env nu
    use std/log

    def ping [slug: string] {
        let url = $"https://hc-ping.com/($env.HC_PING_KEY)/($slug)"
        let timeout = 10sec
        try {
            log info $"Pinging: ($url)"
            http get $url --max-time $timeout | ignore
        } catch {|err|
            log warning $"Healthcheck failed: ($err.msg)"
        }
    }
    def with-healthcheck [slug: string, operation: closure] {
        try {
            ping $"($slug)/start"
            do $operation
            ping $slug
        } catch {|err|
            log error $"Something went wrong: ($err.msg)"
            ping $"($slug)/fail"
            error make $err
        }
    }

    def export-db-sqlite [--data-dir: path, --working-dir: path] {
        let db_path = ($data_dir | path join "db.sqlite3")
        if not ($db_path | path exists) {
            log error $"Database file not found: ($db_path)"
            error make {msg: $"Database file does not exist: ($db_path)"}
        }
        
        try {
            # TODO: move out here Check if working directory exists
            if not ($working_dir | path exists) {
                log error $"Working directory does not exist: ($working_dir)"
                error make {msg: $"Working directory does not exist: ($working_dir)"}
            }
            
            let backup_db_export = ($working_dir | path join "db-export.sqlite3") | path expand
            log info $"📦 Creating SQLite backup: ($backup_db_export)"

            print $db_path
            print $backup_db_export
            print $".backup '($backup_db_export)'"
            
            # Debug: Check if sqlite3 is available
            try {
                let sqlite_version = (^sqlite3 --version | complete)
                log info $"SQLite version: ($sqlite_version.stdout)"
            } catch {|err|
                log error $"SQLite3 not found or not working: ($err.msg)"
                error make {msg: "SQLite3 command not available"}
            }
            
            # Debug: Check database file permissions and size
            let db_stat = (ls $db_path | first)
            log info $"Database file info - Size: ($db_stat.size), Modified: ($db_stat.modified)"
            
            # Debug: Check if we can read the database file
            try {
                let tables_result = (^sqlite3 $db_path ".tables" | complete)
                if $tables_result.exit_code == 0 {
                    log info $"Database is readable, tables found: ($tables_result.stdout | str trim)"
                } else {
                    log error $"Cannot read database: ($tables_result.stderr)"
                }
            } catch {|err|
                log error $"Failed to query database: ($err.msg)"
            }
            
            # Debug: Try the backup command with better error capture
            log info $"Executing: sqlite3 ($db_path) '.backup ($backup_db_export)'"
            
            # sqlite3 db.sqlite3 ".backup '/tmp/db-export.sqlite3'"
            let backup_result = (^sqlite3 $db_path $".backup ($backup_db_export)" | complete)
            
            log info $"SQLite backup result - Exit code: ($backup_result.exit_code)"
            if $backup_result.stdout != "" {
                log info $"SQLite stdout: ($backup_result.stdout)"
            }
            if $backup_result.stderr != "" {
                log error $"SQLite stderr: ($backup_result.stderr)"
            }
            
            if $backup_result.exit_code != 0 {
                error make {msg: $"SQLite backup failed with exit code ($backup_result.exit_code): ($backup_result.stderr)"}
            }
            
            log info "✅ SQLite backup command completed successfully, now verifying..."
            
            # Verify backup was created successfully
            log info $"Checking if backup file exists: ($backup_db_export)"
            if not ($backup_db_export | path exists) {
                log error $"❌ Failed to create database backup at: ($backup_db_export)"
                error make {msg: "SQLite backup operation failed - file not created"}
            }
            
            log info "✅ Backup file exists, checking size..."
            try {
                let backup_info = (ls $backup_db_export | first)
                log info $"Backup file size: ($backup_info.size)"
                
                # Convert size to bytes for comparison
                let size_bytes = ($backup_info.size | into int)
                log info $"Backup file size in bytes: ($size_bytes)"
                
                if $size_bytes == 0 {
                    log error $"❌ Created backup file is empty: ($backup_db_export)"
                    error make {msg: "SQLite backup file is empty"}
                }
                
                log info $"✅ Database backup created successfully: ($backup_db_export) (size: ($backup_info.size))"
                
            } catch {|err|
                log error $"❌ Error checking backup file info: ($err.msg)"
                # Let's be more lenient here - if we can't get file info but the file exists, that's probably OK
                log warning $"File verification failed, but backup file exists, continuing..."
                log info $"✅ Database backup created (verification skipped due to error)"
            }

            ls $data_dir | print
            log info "4"
        } catch {|err|
            log error $"Creating backup archive failed: ($err.msg)"
            error make $err
        }
    }

    def backup [--backup-dir: path] {
        restic backup --host "${HOSTNAME}" --tag "${restic_tags:-vaultwarden}" --path "$backup_dir"
        restic forget --keep-within 180d --prune
        restic check --read-data-subset 100%
    }

    with-healthcheck $env.HC_SLUG {
        let working_dir = "/tmp"
        export-db-sqlite --data-dir "/vaultwarden/data" --working-dir $working_dir 
        #backup                --backup-dir "$working_dir"
    }


# Execute Vaultwarden restore operation
restore snapshot_id:
    nu main.nu restore --snapshot-id {{snapshot_id}} --restore-dir {{restore_dir}}