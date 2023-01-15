const std = @import("std");
const SDL = @import("sdl2-zig");
const Image = SDL.image;
const GameEngine = @import("engine.zig");

const Self = @This();

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .enable_memory_limit = true,
    }){};
    defer {
        const leaked = gpa.deinit();
        if (leaked) @panic("Memory leak :(");
    }
    var engine = try GameEngine.init(gpa.allocator());
    // Note that info level log messages are by default printed only in Debug
    // and ReleaseSafe build modes.
    std.log.info("Zig dash!", .{});
    while (engine.running) {
        //std.log.info("WHILE TRUUUU", .{});
        while (SDL.pollEvent()) |ev| {
            //std.log.info("Current event: {s}", .{@tagName(ev)});
            try engine.handleEvents(ev);
        }
        try engine.draw();
    }
    try engine.deinit();
}
//var app: s.App = undefined;
//var stage: Stage = undefined;
//var bullet: s.Entity = undefined;
//
//    app = s.App{
//        .window = screen,
//        .renderer = try SDL.createRenderer(screen, null, .{ .accelerated = true }),
//        .keyboard = [_]u8{0} ** 350,
//        .delegate = undefined,
//        // TODO: Assign drawing function to delegate for init.
//        //.fire = 0,
//    };
//}
//
//pub fn SdlCleanup() void {
//    SDL.quit();
//    app.window.destroy();
//    app.renderer.destroy();
//}
//
//pub fn prepareScene(ctx: s.App) !void {
//    try ctx.renderer.setColorRGB(0, 0, 0);
//    try ctx.renderer.clear();
//}
//
//pub fn main() anyerror!void {
//    var then: u64 = undefined;
//    var remainder: f64 = undefined;
//
//    try initSdl();
//    defer SdlCleanup();
//    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//    defer arena.deinit();
//    const ally = arena.allocator();
//
//    stage = try Stage.init(app, ally);
//    defer stage.deinit();
//
//    then = SDL.getTicks64();
//    //var size = app.window.getSize();
//    //player = s.Entity{ .health = 100, .x = 100, .y = 100, .dx = 0, .dy = 0, .texture = try loadTxture(app, "./ship2.png") };
//    //bullet = s.Entity{ .health = 100, .x = undefined, .y = undefined, .dx = 0, .dy = 0, .texture = try Draw.loadTxture(app, "./laserp.png") };
//
//    while (true) {
//        try prepareScene(app);
//        // doInput in while:
//        Input.doInput(&app);
//
//        try app.delegate.logic(&stage, &app);
//
//        try app.delegate.draw(&stage, &app);
//
//        Draw.presentScene(app);
//
//        //try Draw.blit(app, player.texture, player.x, player.y);
//        //if (bullet.health > 0) {
//        //    try Draw.blit(app, bullet.texture, bullet.x, bullet.y);
//        //}
//        capFrameRate(&then, &remainder);
//
//        //try app.renderer.setColorRGB(0, 0, 0);
//        //try app.renderer.clear();
//
//        //try app.renderer.setColor(SDL.Color.parse("#F7A41D") catch unreachable);
//        //try app.renderer.drawRect(SDL.Rectangle{
//        //    .x = 270,
//        //    .y = 215,
//        //    .width = 100,
//        //    .height = 50,
//        //});
//
//        //renderer.present();
//    }
//}
//
//pub fn capFrameRate(then: *u64, remainder: *f64) void {
//    var wait: u64 = undefined;
//    var frameTime: u64 = undefined;
//
//    wait = 16 + @floatToInt(u64, remainder.*);
//    frameTime = SDL.getTicks64();
//    wait -= frameTime;
//
//    if (wait < 1) {
//        wait = 1;
//    }
//
//    remainder.* += 0.667;
//    then.* = SDL.getTicks64();
//}
//
