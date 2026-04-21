
const std = @import("std");
const print = std.debug.print;

const fs = std.fs;
const crypto = std.crypto;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;


const same_files_txt    = "backup_same_files.txt";
const copied_files_txt  = "backups_copied_files.txt";
const copied_files_b2_to_b1_txt  = "backups_copied_files_b2_to_b1.txt";
const renamed_files_txt = "backups_renamed_files.txt";

const rename_only_exts = "pdf, djvu, doc, epub, mp3, mp4, zip, rar, fb2, rtf"; // do not compare and rename/mv multiple tiny files like css-js-gifs from folders-that-required-with-saved_web_pages

const HashResult = struct {
  sha256: [32]u8,
  blake2b: [32]u8,
  
  fn format_hex(self: HashResult, allocator: Allocator) ![]const u8 {
    return try std.fmt.allocPrint(allocator, "s256:{x},b2b:{x}", .{
      std.fmt.fmtSliceHexLower(&self.sha256),
      std.fmt.fmtSliceHexLower(&self.blake2b),
    });
  }
  
  fn eql(self: HashResult, other: HashResult) bool {
    return std.mem.eql(u8, &self.sha256, &other.sha256) and
           std.mem.eql(u8, &self.blake2b, &other.blake2b);
  }
};


const FileEntry = struct {
  rel_path: []const u8,
  size: u64,
  hash: ?HashResult = null,
};

const MultiFileEntry = struct {
  base_path: []const u8,
  rel_path: []const u8,
  size: u64,
  hash: ?HashResult = null,
};


fn compute_hashes(absolute_path: []const u8) !HashResult {
  const file = fs.cwd().openFile(absolute_path, .{}) catch |err| {
    print("Error opening file for hashing: {s}\nPath: {s}\n", .{ @errorName(err), absolute_path });
    return err;
  };
  defer file.close();
  
  var sha = crypto.hash.sha2.Sha256.init(.{});
  var blake = crypto.hash.blake2.Blake2b256.init(.{});
  
  var buffer: [64 * 1024]u8 = undefined;
  while(true){
    const bytes_read = try file.read(&buffer);
    if(bytes_read == 0) break;
    sha.update(buffer[0..bytes_read]);
    blake.update(buffer[0..bytes_read]);
  }
  
  var res: HashResult = undefined;
  res.sha256 = sha.finalResult();
  blake.final(&res.blake2b);
  return res;
}

fn scan_dir(allocator: Allocator, base_path: []const u8, sub_path: []const u8, list: *ArrayList(FileEntry)) !void {
  const full_path = if(sub_path.len == 0)
    try allocator.dupe(u8, base_path)
  else
    try fs.path.join(allocator, &[_][]const u8{ base_path, sub_path });
  defer allocator.free(full_path);
  
  var dir = fs.cwd().openDir(full_path, .{ .iterate = true }) catch return;
  defer dir.close();
  
  var iter = dir.iterate();
  while(try iter.next()) |entry|{
    const entry_rel = if(sub_path.len == 0)
      try allocator.dupe(u8, entry.name)
    else
      try fs.path.join(allocator, &[_][]const u8{ sub_path, entry.name });
    
    if(entry.kind == .directory){
      try scan_dir(allocator, base_path, entry_rel, list);
    }else if(entry.kind == .file){
      const stat = try dir.statFile(entry.name);
      try list.append(.{
        .rel_path = entry_rel,
        .size = stat.size,
      });
    }
  }
}


fn mode_sync(allocator: Allocator, src_path: []const u8, dst_path: []const u8, is_backup2backup: bool, is_nocopy: bool) !void {
  var src_files = ArrayList(FileEntry).init(allocator);
  var dst_files = ArrayList(FileEntry).init(allocator);
  
  print("Scanning directories...\n", .{});
  try scan_dir(allocator, src_path, "", &src_files);
  try scan_dir(allocator, dst_path, "", &dst_files);
  
  var dst_map = std.StringHashMap(*FileEntry).init(allocator);
  for(dst_files.items) |*f| try dst_map.put(f.rel_path, f);
  
  var src_map = std.StringHashMap(void).init(allocator);
  for(src_files.items) |f| try src_map.put(f.rel_path, {});
  
  const log_copy = try fs.cwd().createFile(copied_files_txt, .{});
  defer log_copy.close();
  
  const log_rename = try fs.cwd().createFile(renamed_files_txt, .{});
  defer log_rename.close();
  
  const log_b2b_back = if (is_backup2backup) try fs.cwd().createFile(copied_files_b2_to_b1_txt, .{}) else null;
  defer if (log_b2b_back) |l| l.close();
  
  var copied_count: usize = 0;
  var renamed_count: usize = 0;
  
  for(src_files.items) |*src_file|{  // sync - laptop2backup or backup2backup (B1 -> B2)
    const full_src = try fs.path.join(allocator, &[_][]const u8{ src_path, src_file.rel_path });
    src_file.hash = compute_hashes(full_src) catch |err|{
      if(err == error.FileNotFound){
        print("Warning: File disappeared during scan: {s}\n", .{ full_src });
        continue; // so skip this file
      }
      return err;
    };
    
    var action_needed = true;
    var found_duplicate_content: ?[]const u8 = null;
    
    if(dst_map.get(src_file.rel_path)) |dst_file|{
      if(src_file.size == dst_file.size){ // if we have the same file path in backup and same size
        const full_dst = try fs.path.join(allocator, &[_][]const u8{ dst_path, dst_file.rel_path });
        dst_file.hash = compute_hashes(full_dst) catch continue;
        
        if(src_file.hash.?.eql(dst_file.hash.?)){ // and same hash
          action_needed = false; // same files, so do nothing
        }
      }
    }
    
    if(action_needed){ // not same file - so try to search doublings for rename file
      const file_ext = fs.path.extension(src_file.rel_path);
      const is_allowed_rename = blk: {
        if(file_ext.len == 0) break :blk false;
        const clean_ext = if(file_ext[0] == '.') file_ext[1..] else file_ext;
        var it = std.mem.tokenizeAny(u8, rename_only_exts, ", ");
        while (it.next()) |ext| if(std.ascii.eqlIgnoreCase(clean_ext, ext)) break :blk true;
        break :blk false;
      };
      
      if(is_allowed_rename){ // needs to rename - only if allowed file extension
        for(dst_files.items) |*dst_file|{
          if(src_file.size == dst_file.size){
            if(src_map.contains(dst_file.rel_path)) continue;
            
            const full_dst_check = try fs.path.join(allocator, &[_][]const u8{ dst_path, dst_file.rel_path });
            if(dst_file.hash == null) dst_file.hash = compute_hashes(full_dst_check) catch continue;
            
            if(src_file.hash.?.eql(dst_file.hash.?)){
              found_duplicate_content = dst_file.rel_path;
              break;
            }
          }
        }
      }
    }
    
    if(!action_needed) continue;
    
    if(found_duplicate_content) |old_rel|{ // lets rename file in backup
      if(std.mem.eql(u8, old_rel, src_file.rel_path)) continue;
      
      if(!is_nocopy){
        const old_full = try fs.path.join(allocator, &[_][]const u8{ dst_path, old_rel });
        const new_full = try fs.path.join(allocator, &[_][]const u8{ dst_path, src_file.rel_path });
        
        if(fs.path.dirname(new_full)) |d| try fs.cwd().makePath(d);
        try fs.renameAbsolute(old_full, new_full);
      }
      try log_rename.writer().print("{s} -> {s}\n", .{ old_rel, src_file.rel_path });
      renamed_count += 1;
      _ = dst_map.remove(old_rel);
    
    }else{ // lets copy file file to backup -- new file or same file name but file was changed
      if(!is_nocopy){
        const final_dst = try fs.path.join(allocator, &[_][]const u8{ dst_path, src_file.rel_path });
        if(fs.path.dirname(final_dst)) |d| try fs.cwd().makePath(d);
        try fs.cwd().copyFile(full_src, fs.cwd(), final_dst, .{});
      }
      try log_copy.writer().print("{s}\n", .{src_file.rel_path});
      copied_count += 1;
    }
  }
  
  const mode_label = if(is_nocopy) "NOCOPY Backup2Backup (B1 -> B2)" else if(is_backup2backup) "Backup2Backup (B1 -> B2)" else "Laptop2Backup";
  print("{s}: Logged Copied {d}, Logged Renamed {d}\n", .{ mode_label, copied_count, renamed_count });
  
  
  if(is_backup2backup){ // backup2backup (B2 -> B1) -- part 2, copy files for get same backups, with same files
    var b2_to_b1_count: usize = 0;
    for(dst_files.items) |*d_file|{
      var exists_in_b1 = false;
      for(src_files.items) |s_file|{
        if(d_file.size == s_file.size){
          if(d_file.hash == null){
            const f = try fs.path.join(allocator, &[_][]const u8{ dst_path, d_file.rel_path });
            d_file.hash = compute_hashes(f) catch continue;
          }
          if(d_file.hash.?.eql(s_file.hash.?)){
            exists_in_b1 = true;
            break;
          }
        }
      }
      
      if(!exists_in_b1){
        if(!is_nocopy){
          const f_src = try fs.path.join(allocator, &[_][]const u8{ dst_path, d_file.rel_path });
          const f_dst = try fs.path.join(allocator, &[_][]const u8{ src_path, d_file.rel_path });
          if(fs.path.dirname(f_dst)) |d| try fs.cwd().makePath(d);
          try fs.cwd().copyFile(f_src, fs.cwd(), f_dst, .{});
        }
        if(log_b2b_back) |l| try l.writer().print("{s}\n", .{d_file.rel_path});
        b2_to_b1_count += 1;
      }
    }
    const mode_label2 = if(is_nocopy) "NOCOPY Backup2Backup (B2 -> B1)" else "Backup2Backup (B2 -> B1)";
    print("{s}: Logged Copied {d} files\n", .{ mode_label2, b2_to_b1_count });
  }
}


fn mode_find_duplicates(allocator: Allocator, target_path: []const u8, filter_files_exts: []const u8) !void {
  var files = ArrayList(FileEntry).init(allocator);
  print("Scanning directories...\n", .{});
  try scan_dir(allocator, target_path, "", &files);
  
  const log_doubles = try fs.cwd().createFile(same_files_txt, .{});
  defer log_doubles.close();
  
  const is_any = std.mem.eql(u8, filter_files_exts, "any");
  var allowed_exts = ArrayList([]const u8).init(allocator);
  if(!is_any){
    var it = std.mem.tokenizeAny(u8, filter_files_exts, ", ");
    while(it.next()) |ext|{
      const clean_ext = if(ext.len > 0 and ext[0] == '.') ext[1..] else ext; // del . if exists
      try allowed_exts.append(clean_ext);
    }
  }
  
  var size_map = std.AutoHashMap(u64, ArrayList(*FileEntry)).init(allocator); // group files by size for optimization
  for(files.items) |*f|{
    if(!is_any){
      const file_ext = fs.path.extension(f.rel_path);
      const clean_file_ext = if(file_ext.len > 0 and file_ext[0] == '.') file_ext[1..] else file_ext;
      
      var found = false;
      for(allowed_exts.items) |ext|{
        if(std.ascii.eqlIgnoreCase(clean_file_ext, ext)){
          found = true;
          break;
        }
      }
      if(!found) continue;
    }
    
    var res = try size_map.getOrPut(f.size);
    if (!res.found_existing) res.value_ptr.* = ArrayList(*FileEntry).init(allocator);
    try res.value_ptr.append(f);
  }
  
  var iter = size_map.iterator();
  while(iter.next()) |entry|{
    const list = entry.value_ptr;
    if(list.items.len < 2) continue;
    
    for(list.items) |f|{ // compute hashes for files with same size
      const full = try fs.path.join(allocator, &[_][]const u8{ target_path, f.rel_path });
      f.hash = try compute_hashes(full);
    }
    
    var skip = try allocator.alloc(bool, list.items.len); // for search doubles in list
    @memset(skip, false);
    
    for(list.items, 0..) |f1, i|{
      if(skip[i]) continue;
      var group = ArrayList([]const u8).init(allocator);
      try group.append(f1.rel_path);
      
      for(list.items[i + 1 ..], 0..) |f2, j|{
        if(f1.hash.?.eql(f2.hash.?)){
          try group.append(f2.rel_path);
          skip[i + 1 + j] = true;
        }
      }
      
      if(group.items.len > 1){
        for(group.items, 0..) |path, k|{
          try log_doubles.writer().print("{s}{s}", .{ path, if(k == group.items.len - 1) "" else ", " }); // write to log file doubles
        }
        try log_doubles.writer().print("\n", .{});
      }
    }
  }
  print("Duplicates analysis finished. Check {s}\n", .{ same_files_txt });
}


fn mode_find_duplicates_multi(allocator: Allocator, target_paths: ArrayList([]const u8), filter_files_exts: []const u8) !void {
  var all_multi_files = ArrayList(MultiFileEntry).init(allocator);
  print("Scanning multiple directories...\n", .{});
  
  for(target_paths.items) |path|{
    var temp_list = ArrayList(FileEntry).init(allocator);
    try scan_dir(allocator, path, "", &temp_list);
    for(temp_list.items) |fe|{
      try all_multi_files.append(.{ .base_path = path, .rel_path = fe.rel_path, .size = fe.size });
    }
  }
  
  const log_doubles = try fs.cwd().createFile(same_files_txt, .{});
  defer log_doubles.close();
  
  const is_any = std.mem.eql(u8, filter_files_exts, "any");
  var size_map = std.AutoHashMap(u64, ArrayList(*MultiFileEntry)).init(allocator);
  
  for(all_multi_files.items) |*f|{
    if(!is_any){
      const file_ext = fs.path.extension(f.rel_path);
      const clean_file_ext = if(file_ext.len > 0 and file_ext[0] == '.') file_ext[1..] else file_ext;
      var found = false;
      var it = std.mem.tokenizeAny(u8, filter_files_exts, ", ");
      
      while(it.next()) |ext|{
        if(std.ascii.eqlIgnoreCase(clean_file_ext, if(ext[0] == '.') ext[1..] else ext)){ found = true; break; }
      }
      if(!found) continue;
    }
    
    var res = try size_map.getOrPut(f.size);
    if (!res.found_existing) res.value_ptr.* = ArrayList(*MultiFileEntry).init(allocator);
    try res.value_ptr.append(f);
  }
  
  var iter = size_map.iterator();
  
  while(iter.next()) |entry|{
    const list = entry.value_ptr;
    if(list.items.len < 2) continue;
    
    for(list.items) |f|{
      const full = try fs.path.join(allocator, &[_][]const u8{ f.base_path, f.rel_path });
      f.hash = try compute_hashes(full);
    }
    var skip = try allocator.alloc(bool, list.items.len);
    @memset(skip, false);
    
    for(list.items, 0..) |f1, i|{
      if(skip[i]) continue;
      var group = ArrayList([]const u8).init(allocator);
      const full1 = try fs.path.join(allocator, &[_][]const u8{ f1.base_path, f1.rel_path });
      try group.append(full1);
      for(list.items[i + 1 ..], 0..) |f2, j|{
        if(f1.hash.?.eql(f2.hash.?)){
          const full2 = try fs.path.join(allocator, &[_][]const u8{ f2.base_path, f2.rel_path });
          try group.append(full2);
          skip[i + 1 + j] = true;
        }
      }
      
      if(group.items.len > 1){
        for(group.items, 0..) |path, k| try log_doubles.writer().print("{s}{s}", .{ path, if(k == group.items.len - 1) "" else ", " });
        try log_doubles.writer().print("\n", .{});
      }
    }
  }
  print("Multi-folder duplicates analysis finished. Check {s}\n", .{ same_files_txt });
}


pub fn main() !void {
  var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
  defer arena.deinit();
  const allocator = arena.allocator();
  
  const args = try std.process.argsAlloc(allocator);
  fs.cwd().access(args[1], .{}) catch { print("Source directory not found: {s}\n", .{ args[1] }); return; };
  if(!std.mem.eql(u8, args[2], "find_doubles")){ fs.cwd().access(args[2], .{}) catch { print("Destination directory not found: {s}\n", .{args[2]}); return; }; }
  
  if(args.len >= 3 and std.mem.eql(u8, args[2], "find_doubles")){ // find doubles in dir (or list of dirs) subdirs included, last arg = files_extension(s) = any | "ext1, ext2, ext3, etc"
    const filter_files_exts = if(args.len == 4) args[3] else "any";
    
    if (args[1].len > 0 and args[1][0] == '[') {
      var target_paths = ArrayList([]const u8).init(allocator);
      var it = std.mem.tokenizeAny(u8, args[1], "[]\", ");
      while(it.next()) |p| try target_paths.append(p);
      try mode_find_duplicates_multi(allocator, target_paths, filter_files_exts);
    } else {
      try mode_find_duplicates(allocator, args[1], filter_files_exts);
    }
  
  }else if(args.len == 3){ // laptop2backup
    try mode_sync(allocator, args[1], args[2], false, false);
  
  }else if(args.len == 4 and std.mem.eql(u8, args[3], "backup2backup")){ // backup2backup
    try mode_sync(allocator, args[1], args[2], true, false);
  
  }else if(args.len == 4 and std.mem.eql(u8, args[3], "nocopy")){ // nocopy backup2backup
    try mode_sync(allocator, args[1], args[2], true, true);
  
  }else{
    print("Usage:\n" ++
      "  Sync:\n" ++
      "    ./beecapy <LAPTOP_DIR> <BACKUP_DIR>\n" ++
      "  Find:\n" ++
      "    ./beecapy <DIR> find_doubles any\n" ++
      "    ./beecapy <DIR> find_doubles \"pdf, djvu, doc\"\n" ++
      "    ./beecapy \"[\\\"/home/u/Documents/books\\\", \\\"/home/u/Downloads\\\", \\\"/media/diskX\\\", \\\"/home/u/сміттячко\\\"]\" find_doubles \"pdf, djvu, doc, epub\"\n" ++
      "  Backup2Backup:\n" ++
      "    ./beecapy <BACKUP_1_DIR> <BACKUP_2_DIR> backup2backup\n" ++
      "  NoCopy Backup2Backup:\n" ++
      "    ./beecapy <BACKUP_1_DIR> <BACKUP_2_DIR> nocopy\n", .{});
    return;
  }
}

