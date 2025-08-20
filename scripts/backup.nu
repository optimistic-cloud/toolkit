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

def main [] {
    log info "backup data"

    with-healthcheck $env.HC_SLUG {
        log info "Starting backup process"
        #let working_dir = "/tmp"
        #export-db-sqlite --data-dir "/vaultwarden/data" --working-dir $working_dir 
        #backup                --backup-dir "$working_dir"
    }
}