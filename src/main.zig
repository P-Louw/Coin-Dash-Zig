const std = @import("std");
const SDL = @import("sdl2-zig");
const SDLC = @import("sdl2-native");
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
    var last: u64 = 0;
    var time: u64 = 0;
    var engine = try GameEngine.init(gpa.allocator());
    std.log.info("Zig dash!", .{});
    while (engine.running) {
        time = SDL.getTicks64();

        while (SDL.pollEvent()) |ev| {
            try engine.handleEvents(ev);
        }
        var dt = @intToFloat(f64, time - last) / 1000.0;
        try engine.update(dt);
        try engine.draw();
        time = last;
        //SDL.delay(5);
    }
    try engine.deinit();
}
