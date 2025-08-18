mod vaultwarden

# Display all available commands across all modules
help:
	@just --list

# Show version information for all installed tools
version:
	@just --version
	@restic version
	@ansible version
