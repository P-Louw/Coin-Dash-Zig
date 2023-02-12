const std = @import("std");
const SDL = @import("sdl2-zig");
const SDLC = @import("sdl2-native");
const Image = SDL.image;
const Ttf = SDL.ttf;
const GameEngine = @import("engine.zig");
const gfx = @import("gfx.zig");

const Level = @This();

const debug_hitbox = true;

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
    x: i32,
    y: i32,
    width: u32,
    height: u32,
    appearence: TextureData,
    hitbox: Hitbox,
};

const Hitbox = struct {
    // Offset relative to entity world coordinate.
    offset_x: i64,
    offset_y: i64,
    width: u64,
    height: u64,
};

pub fn init(screen_x: u32, screen_y: u32) !Level {
    var screen_width = screen_x;
    var screen_height = screen_y;
    const allocator = std.heap.page_allocator;
    //defer allocator.free(memory);
    //
    // Obstacle placement
    //
    //fn place_entity_rng(ally: std.mem.Allocator, coord_rng: anytype, width: u32, height: u32, texture_data: TextureData, hbox: Hitbox, collidables: [][]GameEntity) !void {
    //var x = coord_rng.rng.intRangeAtMost(i32, 0, @intCast(i32, coord_rng.x_max));
    //var y = coord_rng.rng.intRangeAtMost(i32, 0, @intCast(i32, coord_rng.y_max));
    var buf_obs = std.ArrayList(GameEntity).init(allocator); //try allocator.alloc(GameEntity, 8);
    var obs_i: usize = 0;
    var prng = std.rand.DefaultPrng.init(1042);
    var rng = &prng.random();
    while (obs_i < 9) : (obs_i += 1) {
        const width = 50;
        const height = 50;
        var obstacle = try allocator.create(GameEntity);
        obstacle.* = GameEntity{
            .x = 0,
            .y = 0,
            .width = width,
            .height = height,
            .appearence = TextureData{
                .static = gfx.texture_cactus,
            },
            .hitbox = Hitbox{
                .offset_x = 10,
                .offset_y = 8,
                .width = width - 20,
                .height = height - 10,
            },
        };
        try place_entity_rng(.{
            .x_max = screen_width - width,
            .y_max = screen_height - height,
            .rng = rng,
        }, obstacle, buf_obs.items);
        try buf_obs.append(obstacle.*);
    }
    //
    // Pickup placement
    //
    var buf_pickup = std.ArrayList(GameEntity).init(allocator);
    var anim_coins = try AnimatedEntity.init(allocator, "coin");
    var pick_i: usize = 0;
    while (pick_i < 5) : (pick_i += 1) {
        const width = 30;
        const height = 30;
        var a_pickup = try allocator.create(GameEntity);
        //var x = rng.intRangeAtMost(i32, 0, @intCast(i32, screen_width - 50));
        //var y = rng.intRangeAtMost(i32, 0, @intCast(i32, screen_width - 50));
        a_pickup.* = GameEntity{
            .x = 0,
            .y = 0,
            .width = width,
            .height = height,
            .appearence = TextureData{
                .animated = anim_coins.*,
            },
            .hitbox = Hitbox{
                .offset_x = 5,
                .offset_y = 5,
                .width = width - 10,
                .height = height - 10,
            },
        };
        try place_entity_rng(.{
            .x_max = screen_width - width,
            .y_max = screen_height - height,
            .rng = rng,
        }, a_pickup, buf_obs.items ++ buf_pickup.items);
        //try place_entity_rng(.{
        //    .x_max = screen_width - width,
        //    .y_max = screen_height - height,
        //    .rng = rng,
        //}, a_pickup, buf_pickup.items);

        // TODO: Extract collision of obstacles and pickups to function or store them together.
        //while (entityOverlapsOneOf(a_pickup, buf_obs.items)) {
        //    a_pickup.x = rng.intRangeAtMost(i32, 0, @intCast(i32, screen_width - 50));
        //    a_pickup.y = rng.intRangeAtMost(i32, 0, @intCast(i32, screen_height - 50));
        //}
        //while (entityOverlapsOneOf(a_pickup, buf_pickup.items)) {
        //    a_pickup.x = rng.intRangeAtMost(i32, 0, @intCast(i32, screen_width - 50));
        //    a_pickup.y = rng.intRangeAtMost(i32, 0, @intCast(i32, screen_height - 50));
        //}
        try buf_pickup.append(a_pickup.*);
    }
    //
    // Player placement
    //
    var new_player = try allocator.create(GameEntity);
    var anim_player = try AnimatedEntity.init(allocator, "player_idle");
    var x = rng.intRangeAtMost(i32, 0, @intCast(i32, screen_width - 50));
    var y = rng.intRangeAtMost(i32, 0, @intCast(i32, screen_width - 50));
    const width = 50;
    const height = 50;
    new_player.* = GameEntity{
        .x = x,
        .y = y,
        .width = 50,
        .height = 50,
        .appearence = TextureData{
            .animated = anim_player.*,
        },
        .hitbox = Hitbox{
            .offset_x = 10,
            .offset_y = 15,
            .width = (width / 2),
            .height = height - 15,
        },
    };
    while (entityOverlapsOneOf(new_player, buf_obs.items)) {
        new_player.x = rng.intRangeAtMost(i32, 0, @intCast(i32, screen_width - 50));
        new_player.y = rng.intRangeAtMost(i32, 0, @intCast(i32, screen_height - 50));
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

/// Checks if entity overlaps with one of the fiven entities.
fn entityOverlapsOneOf(placed: *GameEntity, others: []GameEntity) bool {
    var rect = SDL.Rectangle{
        .x = @intCast(c_int, placed.x + placed.hitbox.offset_x),
        .y = @intCast(c_int, placed.y + placed.hitbox.offset_y),
        .width = @intCast(c_int, placed.hitbox.width),
        .height = @intCast(c_int, placed.hitbox.height),
    };
    for (others) |obj| {
        var other = SDL.Rectangle{
            .x = @intCast(c_int, obj.x + obj.hitbox.offset_x),
            .y = @intCast(c_int, obj.y + obj.hitbox.offset_y),
            .width = @intCast(c_int, obj.hitbox.width),
            .height = @intCast(c_int, obj.hitbox.height),
        };
        if (other.hasIntersection(rect)) {
            return true;
        }
    }
    return false;
}

/// Check if a entity overlaps, if so returns index of colliding entity.
fn entityOverlapsWith(placed: *GameEntity, others: []GameEntity) ?usize {
    var rect = SDL.Rectangle{
        .x = @intCast(c_int, placed.x + placed.hitbox.offset_x),
        .y = @intCast(c_int, placed.y + placed.hitbox.offset_y),
        .width = @intCast(c_int, placed.hitbox.width),
        .height = @intCast(c_int, placed.hitbox.height),
    };
    for (others) |obj, idx| {
        var other = SDL.Rectangle{
            .x = @intCast(c_int, obj.x + obj.hitbox.offset_x),
            .y = @intCast(c_int, obj.y + obj.hitbox.offset_y),
            .width = @intCast(c_int, obj.hitbox.width),
            .height = @intCast(c_int, obj.hitbox.height),
        };
        if (other.hasIntersection(rect)) {
            return idx;
        }
    }
    return null;
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

fn place_entity_rng(rng_coords: anytype, entity: *GameEntity, others: []GameEntity) !void {
    entity.x = @intCast(i32, rng_coords.x_max);
    entity.y = @intCast(i32, rng_coords.y_max);
    while (entityOverlapsOneOf(entity, others)) {
        std.log.info("PLACEMENT COLLIDES: {} - {}", .{ entity.x, entity.y });
        entity.x = rng_coords.rng.intRangeAtMost(i32, 0, @intCast(i32, rng_coords.x_max));
        entity.y = rng_coords.rng.intRangeAtMost(i32, 0, @intCast(i32, rng_coords.y_max));
        std.log.info("PLACEMENT CHANGED: {} - {}", .{ entity.x, entity.y });
    }
}

fn move_player(self: *Level, x: i32, y: i32) void {
    self.player_entity.x = x;
    self.player_entity.y = y;
}

pub fn update(self: *Level, runstate: *bool, dt: f64) !void {
    var change = @floatToInt(i32, dt * self.movement);
    std.log.info("CHANGE: {any}", .{change});
    if (self.keys[@enumToInt(SDL.Scancode.up)]) {
        if (change > self.player_entity.y) {
            self.move_player(self.player_entity.x, 0);
        } else self.move_player(self.player_entity.x, self.player_entity.y - change);
    }
    if (self.keys[@enumToInt(SDL.Scancode.down)]) {
        if ((self.player_entity.y + @intCast(i32, self.player_entity.height)) + change > self.window_area_y) {
            self.move_player(self.player_entity.x, @intCast(i32, self.window_area_y - self.player_entity.height));
        } else self.move_player(self.player_entity.x, self.player_entity.y + change);
    }
    if (self.keys[@enumToInt(SDL.Scancode.left)]) {
        if (change > self.player_entity.x) {
            self.move_player(self.player_entity.x, 0);
        } else self.move_player(self.player_entity.x - change, self.player_entity.y);
    }
    if (self.keys[@enumToInt(SDL.Scancode.right)]) {
        if ((self.player_entity.x + @intCast(i32, self.player_entity.width)) + change > self.window_area_x) {
            self.move_player(@intCast(i32, self.window_area_x - self.player_entity.width), self.player_entity.y);
        } else self.move_player(self.player_entity.x + change, self.player_entity.y);
    }
    // Check gameover:
    if (entityOverlapsOneOf(&self.player_entity, self.obstacles.items)) {
        runstate.* = false;
    }
    // Check pickup:
    if (entityOverlapsWith(&self.player_entity, self.pickups.items)) |idx| {
        _ = self.pickups.orderedRemove(idx);
        self.score += 5;
    }
}

pub fn draw(self: *Level, engine: *GameEngine) !void {
    try self.drawBackground(engine.*);
    try placeItems(engine.*, &self.obstacles);
    try placeItems(engine.*, &self.pickups);
    try self.drawPlayer(engine.*);
    try self.drawScore(engine);
    for (self.pickups.items) |*item| {
        if (entityOverlapsOneOf(item, self.obstacles.items)) {
            try engine.renderer.setColor(SDL.Color.black);
            var box = SDL.Rectangle{
                .x = @intCast(c_int, item.x + item.hitbox.offset_x),
                .y = @intCast(c_int, item.y + item.hitbox.offset_y),
                .width = @intCast(c_int, item.hitbox.width),
                .height = @intCast(c_int, item.hitbox.height),
            };
            try engine.renderer.fillRect(box);
            try engine.renderer.setColorRGB(0xF7, 0xA4, 0x1D);
        }
    }
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
        if (debug_hitbox) {
            var box = SDL.Rectangle{
                .x = @intCast(c_int, rect.x + rect.hitbox.offset_x),
                .y = @intCast(c_int, rect.y + rect.hitbox.offset_y),
                .width = @intCast(c_int, rect.hitbox.width),
                .height = @intCast(c_int, rect.hitbox.height),
            };
            try engine.renderer.drawRect(box);
        }
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
    if (debug_hitbox) {
        try engine.renderer.drawRect(SDL.Rectangle{
            .x = @intCast(c_int, self.player_entity.x + self.player_entity.hitbox.offset_x),
            .y = @intCast(c_int, self.player_entity.y + self.player_entity.hitbox.offset_y),
            .width = @intCast(c_int, self.player_entity.hitbox.width),
            .height = @intCast(c_int, self.player_entity.hitbox.height),
        });
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
