const std = @import("std");
const SDL = @import("sdl2-zig");
const SDLC = @import("sdl2-native");

pub fn hasIntersection(a: *SDL.Rectangle, b: *SDL.Rectangle) bool {
    if (SDLC.SDL_HasIntersection(@ptrCast(*SDLC.SDL_Rect, a), @ptrCast(*SDLC.SDL_Rect, b)) == 1) {
        return true;
    }
    return false;
}

pub fn intersectRectAndLine(rect: *SDL.Rectangle, x1: *c_int, y1: *c_int, x2: *c_int, y2: *c_int) bool {
    var result = SDLC.SDL_IntersectRectAndLine(
        @ptrCast(*SDLC.SDL_Rect, rect),
        x1,
        y1,
        x2,
        y2,
    );
    if (result == 1) {
        return true;
    }
    return false;
}
