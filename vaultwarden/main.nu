use std/log

def backup_db_sqlite [] {
    print "🔧 Vaultwarden Backup Tool backup sqlite"
}

def "main restore" [--restore-id: number --restore-path: path] {
    print $"🔧 Vaultwarden Backup Tool main restore ($restore_id)"
}

def main [--backup-data: path] {
    print "🔧 Vaultwarden Backup Tool"

    if not ($backup_data | path exists) {
        log error $"Backup path does not exist: ($backup_data)"
        error make {msg: $"Backup path does not exist: ($backup_data)"}
    }

    backup_db_sqlite 

}