const std = @import("std");
const SDL = @import("sdl2-zig");
const Image = SDL.image;
const Gfx = @import("gfx.zig");
const Menu = @import("menu.zig");
const Level = @import("level.zig");

const Self = @This();

pub const window_width = 480;
pub const window_height = 720;

window: SDL.Window,
renderer: SDL.Renderer,

//timestep: u32,
allocator: std.mem.Allocator,
state: SceneState,
game_state: GameState,
running: bool,
gfx: Gfx,

var now: f64 = 0; // @intToFloat(f64, SDL.getPerformanceCounter());
var last: f64 = 0;
const SceneState = enum {
    loading,
    menu,
    playing,
    pause,
};

const GameState = union(enum) {
    menu: Menu,
    level: Level,

    fn handleEvents(gs: *GameState, engine: *Self, event: SDL.Event) !void {
        return switch (gs.*) {
            inline else => |*state| state.handleEvents(engine, event),
        };
    }

    fn deinit(gs: GameState, renderer: SDL.Renderer) !void {
        return switch (gs) {
            inline else => |state| state.deinit(renderer),
        };
    }

    fn update(gs: *GameState, dt: f64) !void {
        return switch (gs.*) {
            inline else => |*state| state.update(dt),
        };
    }

    fn draw(gs: *GameState, engine: *Self) !void {
        return switch (gs.*) {
            inline else => |*state| state.draw(engine),
        };
    }
};

pub fn init(ally: std.mem.Allocator) !Self {
    try SDL.init(.{
        .video = true,
        .events = true,
        .audio = true,
    });
    try Image.init(.{
        .jpg = true, // IMG_INIT_JPG = 1,
        .png = true, // IMG_INIT_PNG = 2,
        .tif = true, // IMG_INIT_TIF = 4,
        .webp = true, // IMG_INIT_WEBP = 8,
    });
    try SDL.ttf.init();
    var engine = Self{
        .allocator = ally,
        .window = try SDL.createWindow(
            "Zig dash",
            .{ .centered = {} },
            .{ .centered = {} },
            Self.window_width,
            Self.window_height,
            .{ .vis = .shown },
        ),
        // Start on the menu state:
        .state = .menu,
        .gfx = try Gfx.init(ally),
        .game_state = GameState{ .menu = Menu.init() },
        .running = true,
        .renderer = undefined,
    };
    engine.renderer = try SDL.createRenderer(engine.window, null, .{ .accelerated = true });
    //try engine.game_state.init();
    try engine.renderer.setColorRGB(0xF7, 0xA4, 0x1D);
    try engine.renderer.clear();
    return engine;
}

pub fn deinit(engine: *Self) !void {
    defer SDL.quit();
    defer Image.quit();
    defer SDL.ttf.quit();
    try engine.game_state.deinit(engine.renderer);
    engine.gfx.deinit();
    engine.window.destroy();
    engine.renderer.destroy();
}

pub fn changeState(engine: *Self, next_state: SceneState) !void {
    std.log.info("Current state is: {}", .{@TypeOf(engine.state)});
    std.log.info("Next state is: {}", .{@TypeOf(next_state)});
    switch (engine.state) {
        .loading => {},
        .menu => {
            try switch (next_state) {
                .playing => {
                    try engine.game_state.deinit(engine.renderer);
                    engine.game_state = GameState{ .level = try Level.init(window_width, window_height) };
                    engine.state = .playing;
                },
                // TODO: Throw invalid state switch error.
                else => error.InvalidStateTransition,
            };
        },
        .playing => {},
        .pause => {},
    }
}

pub fn handleEvents(self: *Self, event: SDL.Event) !void {
    std.log.info("Engine state: {s}", .{@tagName(self.state)});
    try switch (event) {
        .quit => self.running = false,
        else => self.game_state.handleEvents(self, event),
    };
}

pub fn update(engine: *Self, dt: f64) !void {
    try engine.game_state.update(dt);
}

pub fn draw(self: *Self) !void {
    try self.renderer.clear();
    try self.game_state.draw(self);
    self.renderer.present();
}

pub fn quit() !void {}
