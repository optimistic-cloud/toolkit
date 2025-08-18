# Show all available commands with descriptions
help:
	@just --list

# Execute Vaultwarden backup operation
backup:
    nu backup.nu

# Execute Vaultwarden restore operation  
restore:
    nu restore.nu