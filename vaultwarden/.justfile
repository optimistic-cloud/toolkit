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

    def hc_ping [endpoint: string] {
        let url = $"https://hc-ping.com/($env.HC_PING_KEY)/test"
        let full_url = if ($endpoint == "") { $url } else { $"($url)/($endpoint)" }
        let timeout = 10sec
        
        try {
            http get $full_url --max-time $timeout | ignore
            log info $"Successfully called healthcheck endpoint: ($full_url)"
        } catch {|err|
            log error $"Failed to send a ping: ($err.msg)"
            error make {msg: $"Failed to send a ping: ($err.msg)"}
        }
    }
    
    def create_backup_archive [] {
        ^sqlite3 "/vaultwarden/data/db.sqlite3" ".backup '/vaultwarden/data/db-export.sqlite3'"
        
        ^tar -cf - /vaultwarden/data | ^zstd -3q --rsyncable -o /vaultwarden/data/data.tar.zst
        
        if not ("/vaultwarden/data/db-export.sqlite3" | path exists) {
            log error "Database backup failed"
            error make {msg: $"Database backup failed"}
        }
        
        if not ("/vaultwarden/data/data.tar.zst" | path exists) {
            log error "Archive creation failed"
            error make {msg: $"Archive creation failed"}
        }
    }
    
    # def run_restic [] {
    #     let hostname = ($env.HOSTNAME? | default (sys host | get hostname))
    #     let tags = ($env.restic_tags? | default "vaultwarden")
        
    #     try {
    #         print "☁️  Starting restic backup..."
    #         ^restic backup --host $hostname --tag $tags /vaultwarden/data
            
    #         print "🗑️  Cleaning up old snapshots..."
    #         ^restic forget --keep-within "180d" --prune
            
    #         print "✅ Verifying backup integrity..."
    #         ^restic check --read-data-subset "100%"
            
    #         print "🎉 Restic operations completed successfully"
    #     } catch {|err|
    #         print $"❌ Restic operation failed: ($err.msg)"
    #         cleanup
    #     }
    # }
    
    try {
        hc_ping "start"
        
        #create_backup_archive
        
        # # Get list of repository directories
        # let repo_dirs = (ls /vaultwarden/restic-repos/ | where type == dir | get name)
        
        # if ($repo_dirs | length) == 0 {
        #     print "❌ No restic repositories found in /vaultwarden/restic-repos/"
        #     cleanup
        # }
        
        # print $"📋 Found (($repo_dirs | length)) restic repositories"
        
        # # Process each repository
        # for repo in $repo_dirs {
        #     print $"🚀 Processing repository: ($repo | path basename)"
            
        #     # Set environment variables for this repository
        #     $env.HC_PING_KEY = "ascascsscsac"
        #     $env.RESTIC_REPOSITORY = $repo
        #     $env.RESTIC_PASSWORD_FILE = ($repo | path join "password")
        #     $env.RESTIC_CACHE_DIR = "/vaultwarden/restic-cache"
        #     $env.AWS_ACCESS_KEY_ID = "your_aws_access_key_id"
        #     $env.AWS_SECRET_ACCESS_KEY = "your_aws_secret_access_key"
        #     $env.AWS_DEFAULT_REGION = "your_aws_default_region"
            
        #     # Verify password file exists
        #     if not ($env.RESTIC_PASSWORD_FILE | path exists) {
        #         print $"❌ Password file not found: ($env.RESTIC_PASSWORD_FILE)"
        #         continue
        #     }
            
        #     # Run restic operations for this repository
        #     run_restic
            
        #     print $"✅ Repository ($repo | path basename) completed successfully"
        # }
        
        hc_ping ""
        
    } catch {|err|
        log error "Backup failed!"
        error make {msg: $"Backup failed!"}
    }

# Execute Vaultwarden restore operation
restore snapshot_id:
    nu main.nu restore --snapshot-id {{snapshot_id}} --restore-dir {{restore_dir}}
    