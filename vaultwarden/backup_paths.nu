# Cross-platform backup path recommendations for Vaultwarden

# Get optimal backup directory based on OS and environment
export def get_backup_directory [
    --config-override: string = ""  # Override from config file
] {
    # If config specifies a custom path, use it
    if $config_override != "" and $config_override != "auto" {
        if (is_path_suitable $config_override) {
            return $config_override
        } else {
            print $"Warning: Configured backup path '($config_override)' is not suitable, falling back to auto-detection"
        }
    }
    
    # Check if we're in a container environment
    if ("/proc/1/cgroup" | path exists) {
        let cgroup_content = (open /proc/1/cgroup | str trim)
        if ($cgroup_content | str contains "docker" or $cgroup_content | str contains "containerd") {
            # We're in a container - use container-optimized paths
            return (get_container_backup_path)
        }
    }
    
    # Native OS paths
    match ($env.OS? | default (sys host | get name)) {
        "linux" => (get_linux_backup_path),
        "macos" => (get_macos_backup_path), 
        "windows" => (get_windows_backup_path),
        _ => "/tmp/vaultwarden-backup"  # Fallback
    }
}

# Container-optimized backup paths
def get_container_backup_path [] {
    # Prefer mounted volumes over ephemeral storage
    let preferred_paths = [
        "/backup",                    # Dedicated backup volume
        "/var/lib/vaultwarden/backup", # App-specific backup dir
        "/data/backup",               # Data volume backup subdir
        "/tmp/backup",                # Ephemeral (last resort)
    ]
    
    for path in $preferred_paths {
        let parent = ($path | path dirname)
        if ($parent | path exists) and (is_writable $parent) {
            mkdir $path
            return $path
        }
    }
    
    "/tmp/vaultwarden-backup"  # Ultimate fallback
}

# Linux backup paths following FHS (Filesystem Hierarchy Standard)
def get_linux_backup_path [] {
    let user_id = (id -u | into int)
    
    if $user_id == 0 {
        # Root user - system-wide backup location
        let system_paths = [
            "/var/lib/vaultwarden/backup",    # App-specific (best)
            "/var/backups/vaultwarden",       # System backup dir
            "/opt/vaultwarden/backup",        # Application dir
            "/srv/backup/vaultwarden",        # Service data
        ]
        
        for path in $system_paths {
            if (is_path_suitable $path) {
                return $path
            }
        }
    } else {
        # Non-root user - user-specific paths
        let home = ($env.HOME | default "/tmp")
        let user_paths = [
            ($home | path join ".local/share/vaultwarden/backup"),  # XDG Base Dir
            ($home | path join ".vaultwarden/backup"),              # Hidden app dir
            ($home | path join "backups/vaultwarden"),              # User backup dir
        ]
        
        for path in $user_paths {
            if (is_path_suitable $path) {
                return $path
            }
        }
    }
    
    "/tmp/vaultwarden-backup"
}

# macOS backup paths following Apple guidelines
def get_macos_backup_path [] {
    let home = ($env.HOME | default "/tmp")
    let user_id = (id -u | into int)
    
    if $user_id == 0 {
        # Root/system paths
        let system_paths = [
            "/usr/local/var/lib/vaultwarden/backup",
            "/Library/Application Support/Vaultwarden/Backup",
            "/var/db/vaultwarden/backup",
        ]
        
        for path in $system_paths {
            if (is_path_suitable $path) {
                return $path
            }
        }
    } else {
        # User paths following macOS conventions
        let user_paths = [
            ($home | path join "Library/Application Support/Vaultwarden/Backup"),
            ($home | path join "Library/Caches/Vaultwarden/Backup"), 
            ($home | path join ".vaultwarden/backup"),
            ($home | path join "Documents/Backups/Vaultwarden"),
        ]
        
        for path in $user_paths {
            if (is_path_suitable $path) {
                return $path
            }
        }
    }
    
    "/tmp/vaultwarden-backup"
}

# Windows backup paths
def get_windows_backup_path [] {
    let appdata = ($env.APPDATA? | default "C:\\Users\\Default\\AppData\\Roaming")
    let programdata = ($env.PROGRAMDATA? | default "C:\\ProgramData")
    
    let windows_paths = [
        ($programdata | path join "Vaultwarden\\Backup"),
        ($appdata | path join "Vaultwarden\\Backup"),  
        "C:\\Backup\\Vaultwarden",
        "C:\\temp\\vaultwarden-backup",
    ]
    
    for path in $windows_paths {
        if (is_path_suitable $path) {
            return $path
        }
    }
    
    "C:\\temp\\vaultwarden-backup"
}

# Check if a path is suitable for backups
def is_path_suitable [path: string] {
    let parent = ($path | path dirname)
    
    # Parent must exist and be writable
    if not ($parent | path exists) {
        return false
    }
    
    if not (is_writable $parent) {
        return false
    }
    
    # Create the directory if it doesn't exist
    if not ($path | path exists) {
        try {
            mkdir $path
        } catch {
            return false
        }
    }
    
    # Must have sufficient space (check for at least 1GB free)
    try {
        let available = (df $path | get available | first)
        if ($available | into int) < 1000000000 {  # 1GB in bytes
            return false
        }
    } catch {
        # If df fails, assume it's okay
    }
    
    return true
}

# Check if directory is writable
def is_writable [path: string] {
    try {
        let test_file = ($path | path join ".write_test")
        "" | save $test_file
        rm $test_file
        return true
    } catch {
        return false
    }
}

# Get backup file path with timestamp
export def get_backup_file_path [
    filename: string,
    --extension: string = "sqlite3",
    --include-hostname = true,
    --config-backup-dir: string = "",
    --timestamp-format: string = "%Y%m%d_%H%M%S"
] {
    let backup_dir = (get_backup_directory --config-override $config_backup_dir)
    let timestamp = (date now | format date $timestamp_format)
    let hostname = if $include_hostname { 
        ($env.HOSTNAME? | default (sys host | get hostname) | str replace -a "." "_")
    } else { "" }
    
    let full_filename = if $hostname != "" {
        $"($filename)_($hostname)_($timestamp).($extension)"
    } else {
        $"($filename)_($timestamp).($extension)"
    }
    
    $backup_dir | path join $full_filename
}
