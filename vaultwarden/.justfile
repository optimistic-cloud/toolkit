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

    def create-backup-archive [--working-dir: path, --data-dir: path] {
        log info $"Creating backup archive in: ($working_dir)"
        log info $"Creating backup from data in: ($data_dir)"
        # try {
        #     let backup_data_archive = ($working_dir | path join "data.tar.zst") | path expand
        #     let backup_db_export = ($working_dir | path join "db-export.sqlite3") | path expand

        #     ls $data_dir | print

        #     log info "0"
        #     which rsync
        #     rsync -a --delete "$data_dir/" "$working_dir/"
        #     log info "1"

        #     sqlite3 "$data_dir/db.sqlite3" ".backup '$backup_db_export'"
        #     log info "2"
        #     tar -cf - "$working_dir" | zstd -3q --rsyncable -o "$backup_data_archive"
        #     log info "3"

        #     ls $data_dir | print
        #     ls $working_dir | where name != $backup_data_archive | each { |file| rm -rf $file.name }
        #     log info "4"
        #     ls $data_dir | print
        # } catch {|err|
        #     log error $"Creating backup archive failed: ($err.msg)"
        #     error make $err
        # }
    }

    def backup [--backup-dir: path] {
        restic backup --host "${HOSTNAME}" --tag "${restic_tags:-vaultwarden}" --path "$backup_dir"
        restic forget --keep-within 180d --prune
        restic check --read-data-subset 100%
    }

    with-healthcheck $env.HC_SLUG {
        let working_dir = "/var/lib/vaultwarden/backup"
        create-backup-archive --working-dir "$working_dir" --data-dir "/vaultwarden/data/"
        #backup                --backup-dir "$working_dir"
    }


# Execute Vaultwarden restore operation
restore snapshot_id:
    nu main.nu restore --snapshot-id {{snapshot_id}} --restore-dir {{restore_dir}}