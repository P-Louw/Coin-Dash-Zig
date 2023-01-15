const std = @import("std");
const SDL = @import("sdl2-zig");
const SDLC = @import("sdl2-native");
const utils = @import("utils.zig");
const Image = SDL.image;
const Ttf = SDL.ttf;
const GameEngine = @import("engine.zig");
const gfx = @import("gfx.zig");

const Level = @This();

score: u32,
health: usize,
movement: u32 = 10,
player_entity: GameEntity,
obstacles: []SDL.Rectangle, //[8]SDL.Rectangle, //std.ArrayList(GameEntity),
pickups: std.ArrayList(GameEntity),
ally: std.mem.Allocator,

var prng = std.rand.DefaultPrng.init(1042);
const rand = &prng.random();

// TODO: extract player specific animation info.
const AnimatedEntity = struct {
    animation_name: []const u8,
    animation_index: usize,
    flipped: bool,

    pub fn init(ally: std.mem.Allocator) !*AnimatedEntity {
        var self = try ally.create(AnimatedEntity);
        self.* = AnimatedEntity{
            .flipped = false,
            .animation_name = "idle",
            .animation_index = 0,
        };
        return self;
    }

    pub fn next(self: *AnimatedEntity) ![:0]const u8 {
        // TODO: Use StringHashmap to cut down loc.
        if (std.mem.eql(u8, self.animation_name, "hurt")) {
            if ((gfx.player_hurt.len - 1) == self.animation_index) {
                self.animation_index = 0;
                return gfx.player_hurt[self.animation_index];
            }
            self.animation_index += 1;
            return gfx.player_hurt[self.animation_index];
        }
        if (std.mem.eql(u8, self.animation_name, "idle")) {
            if ((gfx.player_idle.len - 1) == self.animation_index) {
                self.animation_index = 0;
                return gfx.player_idle[self.animation_index];
            }
            self.animation_index += 1;
            return gfx.player_idle[self.animation_index];
        }
        if (std.mem.eql(u8, self.animation_name, "run")) {
            if ((gfx.player_run.len - 1) == self.animation_index) {
                self.animation_index = 0;
                return gfx.player_run[self.animation_index];
            }
            self.animation_index += 1;
            return gfx.player_run[self.animation_index];
        }
        return gfx.AssetError.AssetNotFound;
    }
};

const TextureData = union(enum) {
    animated: AnimatedEntity,
    static: [:0]const u8,

    pub fn getAnimTexture(self: *TextureData) gfx.AssetError![:0]const u8 {
        switch (self.*) {
            // TODO: draw statics from here.
            TextureData.static => |img| {
                return img;
            },
            TextureData.animated => |*anim| {
                return try anim.next();
            },
        }
    }
};

const GameEntity = struct {
    x: u32,
    y: u32,
    width: u32,
    height: u32,
    appearence: TextureData,
};

pub fn init(screen_width: u32, screen_height: u32) !Level {
    const allocator = std.heap.page_allocator;
    //defer allocator.free(memory);
    //
    // Obstacle placement
    //
    var buf_obs = std.ArrayList(SDL.Rectangle).init(allocator); //try allocator.alloc(GameEntity, 8);
    var obs_i: usize = 0;
    while (obs_i < 9) : (obs_i += 1) {
        var a_obj = try allocator.create(SDL.Rectangle);
        //std.log.info("Setting up a entity", .{});
        a_obj.* = SDL.Rectangle{
            .x = rand.intRangeAtMost(c_int, 0, @intCast(c_int, screen_width - 50)),
            .y = rand.intRangeAtMost(c_int, 0, @intCast(c_int, screen_height - 50)),
            .width = 50,
            .height = 50,
        };
        for (buf_obs.items) |*item| {
            while (utils.hasIntersection(a_obj, item)) {
                a_obj.x = rand.intRangeAtMost(c_int, 0, @intCast(c_int, screen_width - 50));
                a_obj.y = rand.intRangeAtMost(c_int, 0, @intCast(c_int, screen_height - 50));
            }
        }
        try buf_obs.append(a_obj.*);
    }

    //
    // Pickup placement
    //
    var buf_pickup = try std.ArrayList(GameEntity).init(allocator);
    var pick_i: usize = 0;
    while (pick_i < 5) : (pick_i += 1) {
        var a_pickup = try allocator.create(GameEntity);
        a_pickup.* = GameEntity{
            .x = rand.intRangeAtMost(c_int, 0, @intCast(c_int, screen_width - 50)),
            .y = rand.intRangeAtMost(c_int, 0, @intCast(c_int, screen_height - 50)),
            .width = 50,
            .height = 50,
            .appearence = TextureData{
                .animated = 
            },
        };
    }

    //
    // Player placement
    //
    var new_player = try allocator.create(GameEntity);
    var anim = try AnimatedEntity.init(allocator);
    new_player.* = GameEntity{
        .x = rand.intRangeAtMost(u32, 0, screen_width - 50),
        .y = rand.intRangeAtMost(u32, 0, screen_height - 50),
        .width = 50,
        .height = 50,
        .appearence = TextureData{
            .animated = anim.*,
        },
    };
    while (entityOverlapsOneOf(new_player, buf_obs.items)) {
        new_player.x = rand.intRangeAtMost(u32, 0, screen_width - 50);
        new_player.y = rand.intRangeAtMost(u32, 0, screen_height - 50);
    }

    //
    // Setup level
    //
    var it = Level{
        .score = 0,
        .health = 100,
        .player_entity = new_player.*,
        .obstacles = try buf_obs.toOwnedSlice(),
        .coins = std.ArrayList(GameEntity).init(allocator),
        .ally = allocator,
    };
    return it;
}

fn entityOverlapsOneOf(placed: *GameEntity, others: []SDL.Rectangle) bool {
    var rect = SDL.Rectangle{
        .x = @intCast(c_int, placed.x),
        .y = @intCast(c_int, placed.y),
        .width = @intCast(c_int, placed.width),
        .height = @intCast(c_int, placed.height),
    };
    for (others) |*obj| {
        if (utils.hasIntersection(obj, &rect)) {
            return true;
        }
    }
    return false;
}

pub fn deinit(self: Level, renderer: SDL.Renderer) !void {
    //txt_font.close();
    //self.ally.free(self.obstacles);
    // This throws a pointer union access error!?
    //self.ally.destroy(self.player_entity);
    self.ally.free(self.obstacles);
    //_ = self;
    _ = renderer;
    //self.coins.deinit();
    //self.obstacles.deinit();
}

pub fn handleEvents(self: *Level, engine: *GameEngine, event: SDL.Event) !void {
    //std.log.info("Handle menu events.", .{});
    switch (event) {
        .quit => engine.running = false,
        .key_up => |key| {
            switch (key.scancode) {
                .@"return" => {
                    //std.log.info("Change state from menu", .{});
                    try engine.changeState(.playing);
                },
                // TODO: Should go to pause.
                .escape => engine.running = false,
                else => {},
            }
        },
        .key_down => |key| {
            switch (key.scancode) {
                .up => {
                    if (self.player_entity.y < self.movement) {
                        self.player_entity.y = 0;
                    } else self.player_entity.y -= self.movement;
                },
                .down => {
                    //self.player_entity.y =
                    if (self.player_entity.y + self.player_entity.height >= GameEngine.window_height) {
                        self.player_entity.y = GameEngine.window_height - self.player_entity.height;
                    } else self.player_entity.y += self.movement;
                },
                .left => {
                    self.player_entity.appearence.animated.flipped = true;
                    if (self.player_entity.x < self.movement) {
                        self.player_entity.x = 0;
                    } else self.player_entity.x -= self.movement;
                },
                .right => {
                    self.player_entity.appearence.animated.flipped = false;
                    if (self.player_entity.x + self.player_entity.width >= GameEngine.window_width) {
                        self.player_entity.x = GameEngine.window_width - self.player_entity.width;
                    } else self.player_entity.x += self.movement;
                },
                else => {},
            }
        },
        else => {},
    }
}
pub fn update() !void {}

pub fn draw(level: *Level, engine: *GameEngine) !void {
    try level.drawBackground(engine.*);
    try level.drawObstacles(engine.*);
    try level.drawPlayer(engine.*);
    try level.drawScore(engine);
    engine.renderer.present();
    //try engine.renderer.setColorRGB(0xF7, 0xA4, 0x1D);
}

fn placePickup() void {}

fn drawPlayer(self: *Level, engine: GameEngine) !void {
    const resource = try self.player_entity.appearence.getAnimTexture();
    const img = try SDL.image.loadTextureMem(engine.renderer, resource[0..], SDL.image.ImgFormat.png);
    const flipped = if (self.player_entity.appearence.animated.flipped) SDL.RendererFlip.horizontal else SDL.RendererFlip.none;
    try engine.renderer.copyEx(img, SDL.Rectangle{
        .x = @intCast(c_int, self.player_entity.x),
        .y = @intCast(c_int, self.player_entity.y),
        .width = @intCast(c_int, self.player_entity.width),
        .height = @intCast(c_int, self.player_entity.height),
    }, null, 0, null, flipped);
}

fn drawObstacles(self: Level, engine: GameEngine) !void {
    const cactus_img = try SDL.image.loadTextureMem(engine.renderer, gfx.texture_cactus[0..], SDL.image.ImgFormat.png);
    defer cactus_img.destroy();
    for (self.obstacles) |rect| {
        try engine.renderer.copy(cactus_img, rect, null);
    }
}

fn drawBackground(self: Level, engine: GameEngine) !void {
    const grass_img = try SDL.image.loadTextureMem(engine.renderer, gfx.texture_grass[0..], SDL.image.ImgFormat.png);
    defer grass_img.destroy();
    _ = self;
    var x: c_int = 0;
    var y: c_int = 0;
    const texture_data = try grass_img.query();
    const width = @intCast(c_int, texture_data.width);
    const height = @intCast(c_int, texture_data.height);
    while (y < (12 * height)) : ({
        y += height;
        x = 0;
    }) {
        while (x < (8 * width)) : (x += width) {
            try engine.renderer.copy(grass_img, SDL.Rectangle{
                .x = x,
                .y = y,
                .width = width,
                .height = height,
            }, null);
        }
    }
}

fn drawScore(self: Level, engine: *GameEngine) !void {
    //std.log.info("Drawing score!", .{});
    var score_buff: [46]u8 = undefined;
    const score_str = try std.fmt.bufPrintZ(&score_buff, "{d}", .{self.score});
    var txt_texture = try gfx.font_texture_load(engine.renderer, &engine.gfx.fontTitle, score_str);
    defer txt_texture.destroy();
    var txtInfo = try txt_texture.query();
    var dst: SDL.Rectangle = SDL.Rectangle{
        .x = @intCast(c_int, ((GameEngine.window_width / 2) - (txtInfo.width / 2))),
        .y = @intCast(c_int, 10),
        .width = @intCast(c_int, txtInfo.width),
        .height = @intCast(c_int, txtInfo.height),
    };
    try engine.renderer.copy(txt_texture, dst, null);
}
