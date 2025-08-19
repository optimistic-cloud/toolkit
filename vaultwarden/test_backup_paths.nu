#!/usr/bin/env nu

# Test script to show optimal backup paths for different environments

use backup_paths.nu *

print "=== Backup Path Analysis ==="
print ""

# Show current environment detection
print $"Current OS: (sys host | get name)"
print $"Current User ID: (id -u)"
print $"Hostname: (sys host | get hostname)"
print ""

# Test auto-detection
print "=== Auto-detected Backup Directory ==="
let auto_path = (get_backup_directory)
print $"Auto-detected path: ($auto_path)"
print ""

# Test custom configuration override
print "=== Configuration Override Tests ==="
let test_configs = [
    "/custom/backup/path",
    "/var/backups/vaultwarden", 
    "/tmp/test-backup",
    "auto"
]

for config in $test_configs {
    let result_path = (get_backup_directory --config-override $config)
    print $"Config '($config)' -> '($result_path)'"
}
print ""

# Test file path generation
print "=== Sample Backup File Paths ==="
let sample_db_path = (get_backup_file_path "vaultwarden_db" --extension "sqlite3")
let sample_archive_path = (get_backup_file_path "vaultwarden_data" --extension "tar.zst")

print $"Database backup: ($sample_db_path)"
print $"Archive backup: ($sample_archive_path)"
print ""

# Test without hostname
let sample_no_hostname = (get_backup_file_path "test" --include-hostname=false)
print $"Without hostname: ($sample_no_hostname)"
print ""

# Environment info for debugging
print "=== Environment Debug Info ==="
print $"HOME: ($env.HOME? | default 'not set')"
print $"USER: ($env.USER? | default 'not set')"
print $"HOSTNAME: ($env.HOSTNAME? | default 'not set')"

# Check if we're in a container
if ("/proc/1/cgroup" | path exists) {
    let cgroup_content = (open /proc/1/cgroup | str trim)
    print $"Container detected: (($cgroup_content | str contains 'docker') or ($cgroup_content | str contains 'containerd'))"
} else {
    print "Container detected: false (no /proc/1/cgroup)"
}
