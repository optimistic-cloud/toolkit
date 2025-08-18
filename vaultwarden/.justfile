data_path := "/vaultwarden/data"
restore_path := "/vaultwarden/restore"

# Show all available commands with descriptions
help:
	@just --list

# Execute Vaultwarden backup operation
backup:
    nu main.nu --backup-data {{data_path}}

# Execute Vaultwarden restore operation  
restore restic_snapshot_id:
    nu main.nu restore --restore-id {{restic_snapshot_id}} --restore-path {{restore_path}}