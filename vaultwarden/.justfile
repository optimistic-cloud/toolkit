data_dir := "/vaultwarden/data"
restore_dir := "/vaultwarden/restore"
restic_cache_dir := "/vaultwarden/restic-cache"

# Show all available commands with descriptions
help:
	@just --list

# Execute Vaultwarden backup operation
backup:
    nu main.nu \
        --backup-data {{data_dir}} \
        --restic-cache-dir {{restic_cache_dir}}

# Execute Vaultwarden restore operation  
restore snapshot_id:
    nu main.nu restore \
        --snapshot-id {{snapshot_id}} \
        --restore-dir {{restore_dir}}