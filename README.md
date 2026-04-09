# beecapy 🐝 for backups 🍯
tool for semi-manual & semi-automatic backups (file diff - check and copy) on linux  
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
```

todo version with html page as GUI  
todo version with GUI and/or TUI  

