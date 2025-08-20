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

def export-db-sqlite [--database: path, --target: path] {
    if not ($database | path exists) {
        log error $"Database file not found: ($database)"
        error make {msg: $"Database file does not exist: ($database)"}
    }
    
    log debug $"📦 Creating SQLite backup: ($target)"

    try {
        let backup_result = (^sqlite3 $database $".backup ($target)" | complete)

        if $backup_result.exit_code != 0 {
            log error $"SQLite backup failed with exit code: ($backup_result.exit_code)"
            if $backup_result.stderr != "" {
                log error $"SQLite stderr: ($backup_result.stderr)"
            }
            error make {msg: $"SQLite backup failed: ($backup_result.stderr)"}
        }
        
        log debug $"SQLite backup completed with exit code: ($backup_result.exit_code)"
        
        if not ($target | path exists) {
            error make {msg: "Backup file was not created"}
        }
        
        log info $"✅ Database backup created successfully: ($target)"
        
    } catch {|err|
        log error $"SQLite backup operation failed: ($err.msg)"
        error make $err
    }
}

def backup [--backup-dir: path] {
    restic backup --host "${HOSTNAME}" --tag "${restic_tags:-vaultwarden}" --path "$backup_dir"
    restic forget --keep-within 180d --prune
    restic check --read-data-subset 100%
}

def main [] {
    with-healthcheck $env.HC_SLUG {
        let working_dir = "/tmp"
        export-db-sqlite --database "/vaultwarden/data/db.sqlite3" --target "/tmp/db-export.sqlite3"
        ls /vaultwarden/data/ | print

        #backup                --backup-dir "$working_dir"
    }
}