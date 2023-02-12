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
movement: f64 = 200,
/// Array size of nr possible keysm, bool to show if active.
keys: [350]bool,
player_entity: GameEntity,
obstacles: std.ArrayList(GameEntity),
pickups: std.ArrayList(GameEntity),
ally: std.mem.Allocator,
rand: std.rand.Random,
window_area_x: u32,
window_area_y: u32,

const AnimatedEntity = struct {
    animation_name: []const u8,
    animation_index: usize,
    flipped: bool,

    pub fn init(ally: std.mem.Allocator, anim_name: []const u8) !*AnimatedEntity {
        var self = try ally.create(AnimatedEntity);
        self.* = AnimatedEntity{
            .flipped = false,
            .animation_name = anim_name,
            .animation_index = 0,
        };
        return self;
    }

    pub fn setAnimation(self: *AnimatedEntity, name: []const u8) void {
        self.animation_name = name;
        self.animation_index = 0;
    }

    /// Gets next texture or first if at end of animation series, increments or resets current
    pub fn next(self: *AnimatedEntity, asset_manager: gfx) ![:0]const u8 {
        // TODO: pull gfx/asset manager from the engine.
        errdefer std.log.info("ANIM NAME: {s}", .{self.animation_name});
        if (asset_manager.animations.get(self.animation_name)) |anims| {
            if ((anims.len - 1) == self.animation_index) {
                self.animation_index = 0;
            } else self.animation_index += 1;
            return anims[self.animation_index];
        }
        return gfx.AssetError.AssetNotFound;
    }
};

const TextureData = union(enum) {
    animated: AnimatedEntity,
    static: [:0]const u8,

    pub fn getAnimTexture(self: *TextureData, resource: gfx) [:0]const u8 {
        switch (self.*) {
            // TODO: draw statics from here.
            TextureData.static => |img| {
                return img;
            },
            TextureData.animated => |*anim| {
                return anim.next(resource) catch unreachable;
            },
        }
    }
};

const GameEntity = struct {
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
    appearence: TextureData,
};

pub fn init(screen_x: u32, screen_y: u32) !Level {
    var screen_width = @intCast(c_int, screen_x);
    var screen_height = @intCast(c_int, screen_y);
    const allocator = std.heap.page_allocator;
    //defer allocator.free(memory);
    //
    // Obstacle placement
    //
    var buf_obs = std.ArrayList(GameEntity).init(allocator); //try allocator.alloc(GameEntity, 8);
    var obs_i: usize = 0;
    var prng = std.rand.DefaultPrng.init(1042);
    var rng = &prng.random();
    while (obs_i < 9) : (obs_i += 1) {
        var a_obj = try allocator.create(GameEntity);
        a_obj.* = GameEntity{
            .x = rng.intRangeAtMost(c_int, 0, screen_width - 50),
            .y = rng.intRangeAtMost(c_int, 0, screen_height - 50),
            .width = 50,
            .height = 50,
            .appearence = TextureData{
                .static = gfx.texture_cactus,
            },
        };
        while (entityOverlapsOneOf(a_obj, buf_obs.items)) {
            a_obj.x = rng.intRangeAtMost(c_int, 0, screen_width - 50);
            a_obj.y = rng.intRangeAtMost(c_int, 0, screen_height - 50);
        }
        try buf_obs.append(a_obj.*);
    }

    //
    // Pickup placement
    //
    var buf_pickup = std.ArrayList(GameEntity).init(allocator);
    var anim_coins = try AnimatedEntity.init(allocator, "coin");
    var pick_i: usize = 0;
    while (pick_i < 5) : (pick_i += 1) {
        var a_pickup = try allocator.create(GameEntity);
        a_pickup.* = GameEntity{
            .x = rng.intRangeAtMost(c_int, 0, screen_width - 50),
            .y = rng.intRangeAtMost(c_int, 0, screen_height - 50),
            .width = 50,
            .height = 50,
            .appearence = TextureData{
                .animated = anim_coins.*,
            },
        };
        // TODO: Extract collision of obstacles and pickups to function or store them together.
        while (entityOverlapsOneOf(a_pickup, buf_obs.items)) {
            a_pickup.x = rng.intRangeAtMost(c_int, 0, screen_width - 50);
            a_pickup.y = rng.intRangeAtMost(c_int, 0, screen_height - 50);
        }
        while (entityOverlapsOneOf(a_pickup, buf_pickup.items)) {
            a_pickup.x = rng.intRangeAtMost(c_int, 0, screen_width - 50);
            a_pickup.y = rng.intRangeAtMost(c_int, 0, screen_height - 50);
        }
        try buf_pickup.append(a_pickup.*);
    }

    //
    // Player placement
    //
    var new_player = try allocator.create(GameEntity);
    var anim_player = try AnimatedEntity.init(allocator, "player_idle");
    new_player.* = GameEntity{
        .x = rng.intRangeAtMost(c_int, 0, screen_width - 50),
        .y = rng.intRangeAtMost(c_int, 0, screen_height - 50),
        .width = 50,
        .height = 50,
        .appearence = TextureData{
            .animated = anim_player.*,
        },
    };
    while (entityOverlapsOneOf(new_player, buf_obs.items)) {
        new_player.x = rng.intRangeAtMost(c_int, 0, screen_width - 50);
        new_player.y = rng.intRangeAtMost(c_int, 0, screen_height - 50);
    }

    //
    // Setup level
    //
    var it = Level{
        .score = 0,
        .player_entity = new_player.*,
        .obstacles = buf_obs,
        .pickups = buf_pickup,
        .ally = allocator,
        .keys = [_]bool{false} ** 350,
        .rand = rng.*,
        .window_area_x = screen_x,
        .window_area_y = screen_y,
    };
    return it;
}

fn entityOverlapsOneOf(placed: *GameEntity, others: []GameEntity) bool {
    var rect = SDL.Rectangle{
        .x = @intCast(c_int, placed.x),
        .y = @intCast(c_int, placed.y),
        .width = @intCast(c_int, placed.width),
        .height = @intCast(c_int, placed.height),
    };
    for (others) |obj| {
        var other = SDL.Rectangle{
            .x = @intCast(c_int, obj.x),
            .y = @intCast(c_int, obj.y),
            .width = @intCast(c_int, obj.width),
            .height = @intCast(c_int, obj.height),
        };
        if (utils.hasIntersection(&other, &rect)) {
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
    //self.ally.free(self.obstacles);
    _ = self;
    _ = renderer;
    //self.coins.deinit();
    //self.obstacles.deinit();
}

pub fn handleEvents(self: *Level, engine: *GameEngine, event: SDL.Event) !void {
    switch (event) {
        .quit => engine.running = false,
        .key_up => |key| {
            switch (key.scancode) {
                .@"return" => {
                    try engine.changeState(.playing);
                },
                // TODO: Should go to pause.
                .escape => engine.running = false,
                .up, .down, .left, .right => {
                    self.keys[@enumToInt(key.scancode)] = false;
                    self.player_entity.appearence.animated.setAnimation("player_idle");
                },
                else => {
                    self.player_entity.appearence.animated.setAnimation("player_idle");
                },
            }
        },
        .key_down => |key| {
            self.keys[@enumToInt(key.scancode)] = true;
            switch (key.scancode) {
                .up => {
                    self.player_entity.appearence.animated.setAnimation("player_run");
                },
                .down => {
                    self.player_entity.appearence.animated.setAnimation("player_run");
                },
                .left => {
                    self.player_entity.appearence.animated.setAnimation("player_run");
                    self.player_entity.appearence.animated.flipped = true;
                },
                .right => {
                    self.player_entity.appearence.animated.setAnimation("player_run");
                    self.player_entity.appearence.animated.flipped = false;
                },
                else => {},
            }
        },
        else => {},
    }
}
pub fn update(self: *Level, runstate: *bool, dt: f64) !void {
    var change = @floatToInt(c_int, dt * self.movement);
    std.log.info("CHANGE: {any}", .{change});
    if (self.keys[@enumToInt(SDL.Scancode.up)]) {
        if (change > self.player_entity.y) {
            self.player_entity.y = 0;
        } else self.player_entity.y -= change;
    }
    if (self.keys[@enumToInt(SDL.Scancode.down)]) {
        if ((self.player_entity.y + self.player_entity.height) + @intCast(c_int, change) > self.window_area_y) {
            self.player_entity.y = @intCast(c_int, self.window_area_y) - self.player_entity.height;
        } else self.player_entity.y += change;
    }
    if (self.keys[@enumToInt(SDL.Scancode.left)]) {
        if (change > self.player_entity.x) {
            self.player_entity.x = 0;
        } else self.player_entity.x -= change;
    }
    if (self.keys[@enumToInt(SDL.Scancode.right)]) {
        if ((self.player_entity.x + self.player_entity.width) + change > self.window_area_x) {
            self.player_entity.x = @intCast(c_int, self.window_area_x) - self.player_entity.width;
        } else self.player_entity.x += change;
    }

    if (entityOverlapsOneOf(&self.player_entity, self.obstacles.items)) {
        runstate.* = false;
    }
}

pub fn draw(self: *Level, engine: *GameEngine) !void {
    try self.drawBackground(engine.*);
    try placeItems(engine.*, &self.obstacles);
    try placeItems(engine.*, &self.pickups);
    try self.drawPlayer(engine.*);
    try self.drawScore(engine);
}

fn placeItems(engine: GameEngine, entities: *std.ArrayList(GameEntity)) !void {
    for (entities.items) |*rect| {
        const resource = rect.appearence.getAnimTexture(engine.gfx);
        const open_img = try SDL.image.loadTextureMem(engine.renderer, resource[0..], SDL.image.ImgFormat.png);
        defer open_img.destroy();
        try engine.renderer.copy(open_img, SDL.Rectangle{
            .x = @intCast(c_int, rect.x),
            .y = @intCast(c_int, rect.y),
            .width = @intCast(c_int, rect.width),
            .height = @intCast(c_int, rect.height),
        }, null);
    }
}

fn drawPlayer(self: *Level, engine: GameEngine) !void {
    const resource = self.player_entity.appearence.getAnimTexture(engine.gfx);
    const img = try SDL.image.loadTextureMem(engine.renderer, resource[0..], SDL.image.ImgFormat.png);
    const flipped = if (self.player_entity.appearence.animated.flipped) SDL.RendererFlip.horizontal else SDL.RendererFlip.none;
    try engine.renderer.copyEx(img, SDL.Rectangle{
        .x = @intCast(c_int, self.player_entity.x),
        .y = @intCast(c_int, self.player_entity.y),
        .width = @intCast(c_int, self.player_entity.width),
        .height = @intCast(c_int, self.player_entity.height),
    }, null, 0, null, flipped);
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
