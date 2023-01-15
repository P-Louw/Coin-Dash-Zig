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
//pub const AnimatedSprite = struct {
//    sprites: std.StringHashMap([][:0]const u8),
//    ally: std.mem.Allocator,
//
//    pub fn init(ally: std.mem.Allocator, sprites) !AnimatedSprite{
//        var map = try sprites.init(ally);
//
//        self = AnimatedSprite{
//            .ally =
//        }
//    }
//
//    pub fn next(self: AnimatedSprite, struct{ sprite_name: []const u8, curr_index: usize}) [:0]const u8 {
//        const sprite = self.sprites[sprite_name];
//        if(sprites)
//    }
//}

pub const AssetError = error{
    AssetNotFound,
};

pub const player_hurt = [_][:0]const u8{
    @embedFile("./assets/player/hurt/player-hurt-1.png"),
    @embedFile("./assets/player/hurt/player-hurt-2.png"),
};

pub const player_idle = [_][:0]const u8{
    @embedFile("./assets/player/idle/player-idle-1.png"),
    @embedFile("./assets/player/idle/player-idle-2.png"),
    @embedFile("./assets/player/idle/player-idle-3.png"),
    @embedFile("./assets/player/idle/player-idle-4.png"),
};

pub const player_run = [_][:0]const u8{
    @embedFile("./assets/player/run/player-run-1.png"),
    @embedFile("./assets/player/run/player-run-2.png"),
    @embedFile("./assets/player/run/player-run-3.png"),
    @embedFile("./assets/player/run/player-run-4.png"),
    @embedFile("./assets/player/run/player-run-5.png"),
    @embedFile("./assets/player/run/player-run-6.png"),
};

pub const coins = [_][:0]const u8{
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

fontTitle: Ttf.Font,
fontDialogue: Ttf.Font,

pub fn init() !Self {
    var gfx = Self{
        .fontTitle = try Ttf.openFontMem(font_Terrablox, true, 46),
        .fontDialogue = try Ttf.openFontMem(font_RubikMedium, true, 12),
    };
    return gfx;
}

/// Create font texture for placement.
pub fn font_texture_load(renderer: SDL.Renderer, font: *Ttf.Font, txt: [:0]const u8) !SDL.Texture {
    //var txt_surface = try txt_font.renderTextSolid(txt, SDL.Color.black);
    var txt_surface = try font.renderTextSolid(txt, SDL.Color.black);
    defer txt_surface.destroy();
    var font_texture = try SDL.createTextureFromSurface(renderer, txt_surface);
    return font_texture;
}
