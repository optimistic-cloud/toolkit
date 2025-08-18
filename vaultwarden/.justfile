data_dir := "/vaultwarden/data"
restore_dir := "/vaultwarden/restore"
restic_cache_dir := "/vaultwarden/restic-cache"

# Show all available commands with descriptions
help:
	@just --list

# Execute Vaultwarden backup operation
backup uuid:
    curl -fsS -m 10 --retry 5 -o /dev/null https://hc-ping.com/{{uuid}}/start

    sqlite3 /vaultwarden/data/db.sqlite3 .backup '/vaultwarden/data/db-export.sqlite3"

    restic backup /vaultwarden/data --host $env.HOSTNAME --tag $restic_tags --quiet
    restic forget --keep-within 180d --prune --quiet
    restic check --read-data-subset 100% --quiet

    # nu main.nu --backup-data {{data_dir}} --restic-cache-dir {{restic_cache_dir}}

    curl -fsS -m 10 --retry 5 -o /dev/null https://hc-ping.com/{{uuid}}

# Execute Vaultwarden restore operation  
restore snapshot_id:
    nu main.nu restore \
        --snapshot-id {{snapshot_id}} \
        --restore-dir {{restore_dir}}