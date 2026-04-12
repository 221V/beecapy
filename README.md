# beecapy 🐝 for backups 🍯
tool for semi-manual & semi-automatic backups (files diff - check and copy) on linux  
tested on (l)ubuntu 22.04 LTS x86_64  

```
zig 0.14.1

# build - CLI version as MVP
zig build-exe ./src/test.zig -O ReleaseFast -femit-bin=beecapy

# usage commands
Sync - copy (from Laptop or PC to Backup):
  ./beecapy <LAPTOP_DIR> <BACKUP_DIR>

Sync - copy (from Backup to Backup):
  ./beecapy <BACKUP_1_DIR> <BACKUP_2_DIR> backup2backup

NoCopy - diff log only (from Backup to Backup):
  ./beecapy <BACKUP_1_DIR> <BACKUP_2_DIR> nocopy

Find - log only (try to find same file in dir and its subdirs):
  ./beecapy <DIR> find_doubles


# logs about
backup_same_files.txt -- same files log for find_doubles mode

backups_copied_files.txt -- copied files log (sync from laptop/PC to backup, or sync from backup_1 to backup_2)

backups_renamed_files.txt -- renamed files log (in backup when sync from laptop/PC to backup, or in backup_2 when sync from backup_1 to backup_2)

backups_copied_files_b2_to_b1.txt -- copied files log (from backup_2 to backup_1 - second part of sync - when sync from backup_1 to backup_2)
```
todo add filters (by file extension, min file size etc) for log-only modes  

todo version with html page as GUI  
todo version with GUI and/or TUI  

