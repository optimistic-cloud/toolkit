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
        if ($target | path exists) { rm $target }
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

def get-vaultwarden-version [] {
    let cfg: record = http get $"http://vaultwarden/api/config" --max-time 10sec
    let version: string = $cfg.version
    return $version
}

def get-restic-version [] {
    let version: string = (restic version | str trim | split row ' ' | get 1)
    return $version
}

def generate-tags [] {
    let vw_version = get-vaultwarden-version
    let restic_version = get-restic-version

    [
        $"vaultwarden_version=($vw_version)"
        $"restic_version=($restic_version)"
    ]
}

def backup [--paths: list<path>, --tags: list<string>] {
    let tag_args = ($tags | each {|t| ['--tag', $t]} | flatten)

    restic backup ...($paths) ...($tag_args)
    restic forget --keep-within 180d --prune
    restic check --read-data-subset 100%
}

def main [] {
    with-healthcheck $env.HC_SLUG {
        export-db-sqlite --database "/vaultwarden/data/db.sqlite3" --target "/tmp/db-export.sqlite3"

        let cfg = open /config.yaml

        for target in $cfg.backups {
            with-env {
                RESTIC_REPOSITORY: $target.repository,
                RESTIC_PASSWORD: $target.password
            } {
                let tags = generate-tags

                cat /vaultwarden.env | print
                cat /config.yaml | print

                backup --paths ["/tmp/db-export.sqlite3", "/vaultwarden/data/", "/vaultwarden.env"] --tags $tags
            }
        }
    }
}