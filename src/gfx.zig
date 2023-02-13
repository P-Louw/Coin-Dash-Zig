const std = @import("std");
const SDL = @import("sdl2-zig");
const Image = SDL.image;
const GameEngine = @import("engine.zig");
const Ttf = SDL.ttf;

pub const Self = @This();

const font_Terrablox = @embedFile("./assets/fonts/TerrabloxRegular.ttf");
const font_RubikMedium = @embedFile("./assets/fonts/RubikMedium-DRPE.ttf");

/// 64x64 grass tile.
pub const texture_grass = @embedFile("./assets/grass.png");
pub const texture_cactus = @embedFile("./assets/cactus.png");

pub const AssetError = error{
    AssetNotFound,
};

pub var player_hurt = [_][:0]const u8{
    @embedFile("./assets/player/hurt/player-hurt-1.png"),
    @embedFile("./assets/player/hurt/player-hurt-2.png"),
};

pub var player_idle = [_][:0]const u8{
    @embedFile("./assets/player/idle/player-idle-1.png"),
    @embedFile("./assets/player/idle/player-idle-2.png"),
    @embedFile("./assets/player/idle/player-idle-3.png"),
    @embedFile("./assets/player/idle/player-idle-4.png"),
};

pub var player_run = [_][:0]const u8{
    @embedFile("./assets/player/run/player-run-1.png"),
    @embedFile("./assets/player/run/player-run-2.png"),
    @embedFile("./assets/player/run/player-run-3.png"),
    @embedFile("./assets/player/run/player-run-4.png"),
    @embedFile("./assets/player/run/player-run-5.png"),
    @embedFile("./assets/player/run/player-run-6.png"),
};

pub var coins = [_][:0]const u8{
    @embedFile("./assets/coin/coin-frame-1.png"),
    @embedFile("./assets/coin/coin-frame-2.png"),
    @embedFile("./assets/coin/coin-frame-3.png"),
    @embedFile("./assets/coin/coin-frame-4.png"),
    @embedFile("./assets/coin/coin-frame-5.png"),
    @embedFile("./assets/coin/coin-frame-6.png"),
    @embedFile("./assets/coin/coin-frame-7.png"),
    @embedFile("./assets/coin/coin-frame-8.png"),
    @embedFile("./assets/coin/coin-frame-9.png"),
    @embedFile("./assets/coin/coin-frame-10.png"),
    @embedFile("./assets/coin/coin-frame-11.png"),
};

pub var powerup = [_][:0]const u8{
    @embedFile("./assets/powerup/pow-frame-1.png"),
    @embedFile("./assets/powerup/pow-frame-2.png"),
    @embedFile("./assets/powerup/pow-frame-3.png"),
    @embedFile("./assets/powerup/pow-frame-4.png"),
    @embedFile("./assets/powerup/pow-frame-5.png"),
    @embedFile("./assets/powerup/pow-frame-6.png"),
    @embedFile("./assets/powerup/pow-frame-7.png"),
    @embedFile("./assets/powerup/pow-frame-8.png"),
    @embedFile("./assets/powerup/pow-frame-9.png"),
    @embedFile("./assets/powerup/pow-frame-10.png"),
};

fontTitle: Ttf.Font,
fontDialogue: Ttf.Font,
animations: std.StringHashMap([][:0]const u8),

pub fn init(ally: std.mem.Allocator) !Self {
    std.log.info("{any}", .{@TypeOf(player_run)});
    var anims = std.StringHashMap([][:0]const u8).init(ally);

    try anims.put("player_hurt", &player_hurt);
    try anims.put("player_idle", &player_idle);
    try anims.put("player_run", &player_run);
    try anims.put("coin", &coins);
    try anims.put("powerup", &powerup);
    var gfx = Self{
        .fontTitle = try Ttf.openFontMem(font_Terrablox, true, 46),
        .fontDialogue = try Ttf.openFontMem(font_RubikMedium, true, 12),
        .animations = anims,
    };
    return gfx;
}

pub fn deinit(gfx: *Self) void {
    gfx.animations.clearAndFree();
}
/// Create font texture for placement.
pub fn font_texture_load(renderer: SDL.Renderer, font: *Ttf.Font, txt: [:0]const u8) !SDL.Texture {
    //var txt_surface = try txt_font.renderTextSolid(txt, SDL.Color.black);
    var txt_surface = try font.renderTextSolid(txt, SDL.Color.black);
    defer txt_surface.destroy();
    var font_texture = try SDL.createTextureFromSurface(renderer, txt_surface);
    return font_texture;
}
