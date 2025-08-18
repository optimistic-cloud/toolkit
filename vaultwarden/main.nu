use std/log

def backup_db_sqlite [database: path] {
    print $"🔧 Vaultwarden Backup Tool backup sqlite on ($database)"
}

def "main restore" [--snapshot-id: number --restore-dir: path] {
    log info $"🔧 Vaultwarden Backup Tool main restore ($snapshot_id)"
}

def main [--backup-data: path --restic-cache-dir: path] {
    print "🔧 Vaultwarden Backup Tool"

    if not ($backup_data | path exists) {
        log error $"Backup path does not exist: ($backup_data)"
        error make {msg: $"Backup path does not exist: ($backup_data)"}
    }

    backup_db_sqlite $"($backup_data)/.db.sqlite3"

}