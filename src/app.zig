
// ws example (without cert - without https-wss)

const std = @import("std");

const zzz = @import("zzz");

//const websocket = @import("zzz/websocket/websocket.zig");
const websocket = zzz.websocket;

const Socket = zzz.tardy.Socket;


const PORT = 3010;
const HOST = "0.0.0.0";


const STACK_SIZE = if (@import("builtin").mode == .Debug)
  1 * 1024 * 1024 // DEBUG = 1mb
else
  16 * 1024; // RELEASE = 16kb


// WebSocket handlers
fn on_ws_connect(conn: websocket.Conn) !void{
  try conn.send("Hello from zzz WebSocket!");
  std.log.info("WebSocket connected", .{});
}


fn on_ws_close(conn: websocket.Conn, code: u16, reason: []const u8) !void{
  _ = conn;
  std.log.info("WS closed: code={d}, reason={s}", .{ code, reason });
}


fn on_ws_message(conn: websocket.Conn, data: []const u8) !void{
  std.log.info("WS Payload received: '{s}' (len: {d})", .{data, data.len});
  
  //const msg = try std.fmt.allocPrint(conn.runtime.allocator, "Echo: {s}", .{data});
  //defer conn.runtime.allocator.free(msg);
  //try conn.send(msg);
  
  try conn.send("Hello from Server!");
  std.log.info("WS <- {s}", .{data});
}


fn on_ws_disconnect(conn: websocket.Conn) !void{
  _ = conn;
  std.log.info("WebSocket disconnected", .{});
}


fn serve_file(ctx: *const zzz.Context, file_path: []const u8, mime: zzz.HTTP.Mime) !zzz.HTTP.Respond {
  var file = try std.fs.cwd().openFile(file_path, .{});
  defer file.close();
  
  const file_size = (try file.stat()).size;
  const content = try ctx.allocator.alloc(u8, file_size);
  defer ctx.allocator.free(content);
  
  _ = try file.readAll(content);
  
  const res = ctx.response;
  res.status = .OK;
  res.mime = mime;
  res.body = content;
  return .standard;
}

fn on_request_index(ctx: *const zzz.Context, _: void) !zzz.HTTP.Respond {
   return serve_file(ctx, "./src/stc/index.html", zzz.HTTP.Mime.HTML);
}


// HTTP fallback
//fn on_request_index(ctx: *const zzz.Context, _: void) !zzz.HTTP.Respond {
//    const res = ctx.response;
//    res.status = .OK;
//    res.mime = zzz.HTTP.Mime.HTML;
//    res.body =
//      \\<html>
//      \\<head><title>zzz + WebSocket</title></head>
//      \\<body>
//      \\<h1>WebSocket Test</h1>
//      \\<script>
//      \\const ws = new WebSocket("ws://localhost:3010/ws"); // same PORT
//      \\ws.onmessage = (e) => console.log("ws <- ", e.data);
//      \\ws.onopen = () => ws.send("Hello from browser!");
//      \\ws.onclose = (e) => console.log("ws closed", e);
//      \\</script>
//      \\</body>
//      \\</html>
//    ;
//    return .standard;
//}


// Upgrade handler
fn on_upgrade(req: *const zzz.Request, proto: []const u8) !bool {
    if (!std.mem.eql(u8, proto, "websocket")) return false;
    
    const key = req.headers.get("Sec-WebSocket-Key") orelse return false;
    const ext = req.headers.get("Sec-WebSocket-Extensions");
    
    var header_buf = std.ArrayList(u8).init(std.heap.page_allocator);
    defer header_buf.deinit();
    
    //const res = try websocket.upgrade(req.socket, req.runtime, std.heap.page_allocator, key, ext, header_buf.writer() );
    const res = try websocket.upgrade(req.socket, req.runtime, req.runtime.allocator, key, ext, header_buf.writer() );
    
    _ = try req.socket.send_all(req.runtime, header_buf.items);
    
    const ws_handler = websocket.Handler{
      .on_connect = on_ws_connect,
      .on_message = on_ws_message,
      .on_close = on_ws_close,
      .on_disconnect = on_ws_disconnect,
    };
    
    if (ws_handler.on_connect) |f| try f(res.conn);
    try req.runtime.spawn(.{ res.conn, ws_handler, std.heap.page_allocator }, websocket.runLoop, STACK_SIZE);
    //try req.runtime.spawn(.{ res.conn, ws_handler, req.runtime.allocator }, websocket.runLoop, STACK_SIZE);
    return true;
}


fn on_ws_endpoint(ctx: *const zzz.Context, _: void) !zzz.HTTP.Respond {
  const req = ctx.request;
  
  const upgrade = req.headers.get("Upgrade");
  if (upgrade == null or !std.mem.eql(u8, upgrade.?, "websocket")) {
    ctx.response.status = .@"Bad Request";
    ctx.response.body = "Expected WebSocket Upgrade";
    return .standard;
  }
  
  const key = req.headers.get("Sec-WebSocket-Key") orelse {
    ctx.response.status = .@"Bad Request";
    return .standard;
  };
  const ext = req.headers.get("Sec-WebSocket-Extensions");
  
  var header_buf = std.ArrayList(u8).init(ctx.allocator);
  defer header_buf.deinit();
  
  const res = try websocket.upgrade(&ctx.socket, ctx.runtime, ctx.allocator, key, ext, header_buf.writer());
  
  _ = try ctx.socket.send_all(ctx.runtime, header_buf.items);
  
  const ws_handler = websocket.Handler{
    .on_connect = on_ws_connect,
    .on_message = on_ws_message,
    .on_close = on_ws_close,
    .on_disconnect = on_ws_disconnect,
  };
  
  if (ws_handler.on_connect) |f| try f(res.conn);
  
  std.log.info("Starting WebSocket Loop...", .{});
  
  //websocket.runLoop(res.conn, ws_handler, ctx.runtime.allocator) catch |err| { // sync loop
  websocket.runLoop(res.conn, ws_handler, std.heap.page_allocator) catch |err| { // sync loop
    std.log.err("WebSocket RunLoop Error: {s}", .{@errorName(err)});
    
    if (err == error.Closed) {
      std.log.info("Socket closed by browser", .{});
    }
  
  };
  
  std.log.info("WebSocket Loop finished", .{});
  return .close;
}



pub fn main() !void{
    //@compileLog("STACK_SIZE = ", STACK_SIZE);
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();
    
    const socket = try Socket.init(.{ .tcp = .{ .host = HOST, .port = PORT } });
    defer socket.close_blocking();
    try socket.bind();
    try socket.listen(1024); // max conn count that are waiting in accept queue
    
    const TardyType = zzz.tardy.Tardy(.auto);
    var tardy = try TardyType.init(allocator, .{});
    //var tardy = try TardyType.init(allocator, .{ .threading = .single });
    defer tardy.deinit();
    
    try tardy.entry(&socket, struct {
        fn entry(rt: *zzz.tardy.Runtime, s: *const Socket) !void {
            const config = zzz.ServerConfig{
                .stack_size = STACK_SIZE,
            };
            
            const static_dir = zzz.tardy.Dir.from_std(try std.fs.cwd().openDir("src/stc", .{})); // serve js-css files from folder
            
            //const home_route = zzz.HTTP.Route.init("/").get({}, on_request);
            //const home_route = zzz.HTTP.Route.init("/").embed_file(.{ .mime = zzz.HTTP.Mime.HTML }, @embedFile("./stc/index.html")); // serve index.html but needs to recompile zig for apply changes in index.html
            const home_route = zzz.HTTP.Route.init("/").get({}, on_request_index); // serve index.html and change without recompile zig
            const ws_route = zzz.HTTP.Route.init("/ws").get({}, on_ws_endpoint);
            const static_route = zzz.HTTP.FsDir.serve("/", static_dir);
            const layers = &[_]zzz.HTTP.Layer{
              home_route.layer(),
              ws_route.layer(),
              static_route,
            };
            
            const router = try rt.allocator.create(zzz.Router);
            router.* = try zzz.Router.init(rt.allocator, layers, .{
              //.not_found = on_request,
              .not_found = on_request_index,
            });
            // no defer router - lifetime per server work
            
            const provisions = try rt.allocator.create(zzz.tardy.Pool(zzz.Provision)); // use heap, not stack
            provisions.* = try zzz.tardy.Pool(zzz.Provision).init(rt.allocator, 1024, .static); // 1024 = pool size
            
            const byte_count = provisions.items.len * @sizeOf(zzz.Provision); // set zeros - for initialized = false
            @memset(@as([*]u8, @ptrCast(provisions.items.ptr))[0..byte_count], 0);
            
            const connection_count = try rt.allocator.create(usize); // use heap, not stack
            connection_count.* = 0;
            
            const accept_queued = try rt.allocator.create(bool);
            accept_queued.* = false;
            
            try rt.spawn(
              .{ rt, config, router, zzz.secsock.SecureSocket.unsecured(s.*), provisions, connection_count, accept_queued },
              zzz.Server.main_frame,
              config.stack_size
            );
        
        } // end fn entry
    }.entry);
}

