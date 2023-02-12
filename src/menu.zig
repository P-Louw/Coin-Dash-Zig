const std = @import("std");
const SDL = @import("sdl2-zig");
const Image = SDL.image;
const GameEngine = @import("engine.zig");
const Gfx = @import("gfx.zig");
const Ttf = SDL.ttf;

const Self = @This();

title: [:0]const u8,
//var txt_font: Ttf.Font = undefined;
//var txt_texture: SDL.Texture = undefined;
// pub fn renderTextShaded(
// self: Font,
// text: [:0]const u8,
// foreground: sdl.Color,
// background: sdl.Color,
// ) !sdl.Surface {

//pub fn font_texture_load(renderer: SDL.Renderer, font: *Ttf.Font, txt: [:0]const u8) !SDL.Texture {
//    //var txt_surface = try txt_font.renderTextSolid(txt, SDL.Color.black);
//    var txt_surface = try font.renderTextSolid(txt, SDL.Color.black);
//    defer txt_surface.destroy();
//    var font_texture = try SDL.createTextureFromSurface(renderer, txt_surface);
//    return font_texture;
//}

pub fn init() Self {
    // Keep font around for later use.
    //txt_font = try Ttf.openFont("./assets/fonts/TerrabloxRegular.ttf", 46);
    var it = Self{ .title = "Sig dash" };
    return it;
}

pub fn deinit(self: Self, renderer: SDL.Renderer) !void {
    _ = self;
    //txt_font.close();
    try renderer.clear();
}

pub fn handleEvents(self: Self, engine: *GameEngine, event: SDL.Event) !void {
    std.log.info("Handle menu events.", .{});
    _ = self;
    //switch (event) {
    //    .quit => engine.running = false,
    //    else => {},
    //}
    switch (event) {
        .quit => engine.running = false,
        .key_up => |key| {
            switch (key.scancode) {
                .@"return" => {
                    std.log.info("Change state from menu", .{});
                    try engine.changeState(.playing);
                },
                // TODO: Should go to pause.
                .escape => engine.running = false,
                else => {},
            }
        },
        else => {},
    }
}
pub fn update(self: *Self, runstate: *bool, dt: f64) !void {
    _ = runstate;
    _ = dt;
    _ = self;
}

pub fn draw(self: Self, engine: *GameEngine) !void {
    // Render menu title
    var txt_texture = try Gfx.font_texture_load(engine.renderer, &engine.gfx.fontTitle, self.title);
    defer txt_texture.destroy();
    var txtInfo = try txt_texture.query();
    var dst: SDL.Rectangle = SDL.Rectangle{
        .x = @intCast(c_int, ((GameEngine.window_width / 2) - (txtInfo.width / 2))),
        .y = @intCast(c_int, txtInfo.height - 10),
        .width = @intCast(c_int, txtInfo.width),
        .height = @intCast(c_int, txtInfo.height),
    };
    try engine.renderer.copy(txt_texture, dst, null);
}
