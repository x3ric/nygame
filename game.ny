#!/bin/ny

use std.core
use std.core.common as common
use std.math as math
use std.os as os
use std.os.args as cli
use std.os.path as ospath
use std.math.parse.img.gif as gif_img
use std.os.ui.render as gfx
use std.os.ui.render.dump as ui_dump
use std.os.ui.render.viewer.batch as ui_batch
use std.os.ui.render.viewer.runtime as ui_runtime
use std.os.ui.window as window
use std.os.ui.window.consts as key

def COLOR_TILE_A = gfx.color_pack(62.0 / 255.0, 38.0 / 255.0, 80.0 / 255.0, 1.0)
def COLOR_TILE_LINE = gfx.color_pack(32.0 / 255.0, 21.0 / 255.0, 39.0 / 255.0, 1.0)
def COLOR_TEXT = gfx.color_pack(1.0, 1.0, 1.0, 1.0)
def COLOR_DIM = gfx.color_pack(152.0 / 255.0, 152.0 / 255.0, 152.0 / 255.0, 1.0)
def COLOR_ACCENT = gfx.color_pack(1.0, 0.0, 1.0, 1.0)
def CHECKED_CELL = 16.0
def SPRITE_SCALE = 4.0
def SPRITE_TEX_FILTER = 0
def SPRITE_TEX_WRAP = 33071
def BASE_SPEED = 135.0
def SPRINT_MULT = 1.55
def CAMERA_LERP = 1.25
def DIAGONAL_LEAN = 30.0
def ROTATION_LERP = 14.0
def ANIM_IDLE_LEFT = 0
def ANIM_IDLE_RIGHT = 1
def ANIM_IDLE_DOWN = 2
def ANIM_IDLE_UP = 3
def ANIM_MOVE_LEFT = 4
def ANIM_MOVE_RIGHT = 5
def ANIM_MOVE_DOWN = 6
def ANIM_MOVE_UP = 7
def ANIM_NAMES = ["IDLE_LEFT", "IDLE_RIGHT", "IDLE_DOWN", "IDLE_UP", "MOVE_LEFT", "MOVE_RIGHT", "MOVE_DOWN", "MOVE_UP"]
def ANIM_KEYS = ["idle", "idle", "idle-down", "idle-up", "move", "move", "move-down", "move-up"]
def SPRITE_KEYS = ["idle", "idle-down", "idle-up", "move", "move-down", "move-up"]
def SPRITE_FILES = {"idle": "idle.gif", "idle-down": "idle-down.gif", "idle-up": "idle-up.gif", "move": "move.gif", "move-down": "move-down.gif", "move-up": "move-up.gif"}

fn f(dict d, str k, f64 v) f64 { float(d.get(k, v)) }
fn i(dict d, str k, int v) int { int(d.get(k, v)) }
fn b(dict d, str k, bool v) bool { bool(d.get(k, v)) }
fn line(f64 x0, f64 y0, f64 x1, f64 y1, f64 t, int c) int { gfx.draw_line_fast(x0, y0, x1, y1, t, c) 0 }
fn text(int font, str s, f64 x, f64 y, any c) int { gfx.draw_text(font, s, x, y, c) 0 }

fn right_text(int font, str s, f64 right, f64 y, any c) int {
   def m = gfx.measure_text(font, s)
   gfx.draw_text(font, s, right - float(m.get(0, 0.0)), y, c) 0
}

fn config(list args) dict {
   def max_frames = int(math.max(cli.int_value_from(args, "--frames", 0), 0))
   def max_seconds = math.max(cli.float_value_from(args, "--seconds", 0.0), 0.0)
   {"title": "Nygame", "width": int(math.max(cli.int_value_from(args, "--width", 1920), 1)),
    "height": int(math.max(cli.int_value_from(args, "--height", 1080), 1)),
    "max_frames": max_frames, "max_seconds": max_seconds,
    "asset_root": cli.value_from(args, "--asset-root", "."),
    "dump": ui_dump.auto_dump_enabled() || cli.flag_from(args, "--dump"),
    "dump_exit": common.env_truthy("NYTRIX_AUTO_DUMP_EXIT") || cli.flag_from(args, "--dump-exit"),
    "dump_path": cli.value_from(args, "--dump-path", ui_dump.auto_dump_path("nygame_frame.png")),
    "dump_frame": int(math.max(cli.int_value_from(args, "--dump-frame", ui_dump.auto_dump_delay_frames(4)), 0)),
    "demo_diagonal": common.env_truthy("NYGAME_DEMO_DIAGONAL") || cli.flag_from(args, "--demo-diagonal"),
    "interactive": max_frames <= 0 && max_seconds <= 0.0}
}

fn asset(str root, str rel) str {
   def p = ospath.join(root, rel)
   def r = ospath.resolve_repo_asset(p)
   (is_str(r) && r.len > 0) ? r : p
}

fn font_size(str name, f64 fallback) int { int(ui_runtime.default_font_size("game", fallback, name, 8.0, 72.0)) }

fn fonts(str root) dict {
   def paths = [asset(root, "res/fonts/Monocraft.ttf"), "res/fonts/Monocraft.ttf", "etc/assets/fonts/monocraft.ttf", "etc/assets/fonts/jetbrains.ttf"]
   def filter = ui_runtime.default_font_filter("game")
   {"title": ui_runtime.mono_font(font_size("TITLE_FONT_SIZE", 22.0), paths, filter),
    "hud": ui_runtime.mono_font(font_size("HUD_FONT_SIZE", 15.0), paths, filter),
    "small": ui_runtime.mono_font(font_size("SMALL_FONT_SIZE", 13.0), paths, filter)}
}

fn open_window(dict cfg) any {
   if(common.env_truthy("NY_UI_HEADLESS")){ gfx.set_backend_type(gfx.BACKEND_MOCK) }
   def win = gfx.init_window(i(cfg, "width", 1920), i(cfg, "height", 1080), to_str(cfg.get("title", "Nygame")), key.WINDOW_CENTER | key.WINDOW_FOCUS_ON_SHOW, "immediate", false, 1)
   if(win && !common.env_truthy("NY_UI_HEADLESS")){ window.focus(win) }
   win
}

fn framebuffer(any win, dict cfg) list {
   def fb = window.get_framebuffer_size(win)
   [math.max(1.0, float(fb.get(0, cfg.get("width", 1920)))), math.max(1.0, float(fb.get(1, cfg.get("height", 1080))))]
}

fn anim_name(int anim) str { ANIM_NAMES.get(anim, "UNKNOWN") }
fn anim_key(int anim) str { ANIM_KEYS.get(anim, "idle") }
fn anim_flip(int anim, bool fallback) bool { match(anim){ ANIM_MOVE_LEFT, ANIM_IDLE_LEFT -> true ANIM_MOVE_RIGHT, ANIM_IDLE_RIGHT -> false _ -> fallback } }
fn key_pair(any win, any a, any bb) bool { window.key_down(win, a) || window.key_down(win, bb) }
fn move_axis(bool positive, bool negative) int { positive == negative ? 0 : (positive ? 1 : -1) }
fn input_axis(any win, bool demo) list {
   if(demo){ return [1, -1] }
   [move_axis(key_pair(win, key.KEY_RIGHT, key.KEY_D), key_pair(win, key.KEY_LEFT, key.KEY_A)),
    move_axis(key_pair(win, key.KEY_DOWN, key.KEY_S), key_pair(win, key.KEY_UP, key.KEY_W))]
}
fn input_anim(int axis_x, int axis_y, int last_idle, bool flipped) list {
   mut anim = last_idle
   if(axis_x > 0){ anim = ANIM_MOVE_RIGHT last_idle = ANIM_IDLE_RIGHT flipped = false }
   elif(axis_x < 0){ anim = ANIM_MOVE_LEFT last_idle = ANIM_IDLE_LEFT flipped = true }
   if(axis_y < 0){ anim = ANIM_MOVE_UP last_idle = ANIM_IDLE_UP }
   elif(axis_y > 0){ anim = ANIM_MOVE_DOWN last_idle = ANIM_IDLE_DOWN }
   [(axis_x == 0 && axis_y == 0) ? last_idle : anim, last_idle, flipped]
}
fn move_rotation(f64 current, f64 dt, int axis_x, int axis_y) f64 {
   def target = (axis_x != 0 && axis_y != 0) ? float(axis_x) * DIAGONAL_LEAN * (axis_y > 0 ? -1.0 : 1.0) : 0.0
   math.lerp(current, target, math.clamp(ROTATION_LERP * dt, 0.0, 1.0))
}
fn update_camera(f64 cam_x, f64 cam_y, f64 px, f64 py, f64 dt) list {
   def t = math.clamp(CAMERA_LERP * dt, 0.0, 1.0)
   [math.lerp(cam_x, px, t), math.lerp(cam_y, py, t)]
}

fn sprite_path(str root, str name) str { asset(root, "res/sprites/player/" + SPRITE_FILES.get(name, "idle.gif")) }
fn sprite_mesh(str path, int idx, any raw, int w, int h, int channels, bool live) dict {
   if(!live || !is_dict(raw) || w <= 0 || h <= 0){ return {} }
   def data = raw.get("data", 0)
   if(!data){ return {} }
   if(channels == 4){
      def tex = gfx.texture_create_rgba(w, h, data, 37, SPRITE_TEX_FILTER, SPRITE_TEX_WRAP, SPRITE_TEX_WRAP, false)
      if(tex > 0){
         return {"tex": tex, "count": 6, "w": w, "h": h, "scale": SPRITE_SCALE, "path": path, "frame": idx}
      }
   }
   def mesh = ui_batch.rgba_mesh(data, w, h, channels, SPRITE_SCALE, 1)
   if(!is_dict(mesh) || int(mesh.get("count", 0)) <= 0){ return {} }
   mesh["path"] = path
   mesh["frame"] = idx
   mesh
}

fn load_sprite(str path, bool live) dict {
   mut out = []
   def bytes = os.file_read(path)
   if(is_ok(bytes)){
      def anim = gif_img.decode_frames(unwrap(bytes))
      if(is_dict(anim)){
         def w, h, ch = int(anim.get("width", 0)), int(anim.get("height", 0)), int(anim.get("channels", 4))
         def frames = anim.get("frames", [])
         if(w > 0 && h > 0 && is_list(frames)){
            for raw in frames{
               def fr = sprite_mesh(path, out.len, raw, w, h, ch, live)
               if(is_dict(fr) && int(fr.get("count", 0)) > 0){ out = out.append(fr) }
            }
         }
      }
   }
   {"frames": out}
}
fn load_sprites(str root) dict {
   mut out = {}
   def live = !common.env_truthy("NY_UI_HEADLESS")
   for name in SPRITE_KEYS{
      def spr = load_sprite(sprite_path(root, name), live)
      if(is_list(spr.get("frames", [])) && spr.get("frames", []).len > 0){ out[name] = spr }
   }
   out
}
fn destroy_sprites(dict sprites) int {
   for name in SPRITE_KEYS{
      def frames = is_dict(sprites.get(name, {})) ? sprites.get(name, {}).get("frames", []) : []
      if(!is_list(frames)){ continue }
      for fr in frames{
         def tex = int(fr.get("tex", 0))
         if(tex > 0){ gfx.texture_destroy(tex) }
         ui_batch.release_mesh(fr)
      }
   }
   0
}
fn frame_count(dict sprites, int anim) int {
   def frames = is_dict(sprites.get(anim_key(anim), {})) ? sprites.get(anim_key(anim), {}).get("frames", []) : []
   (is_list(frames) && frames.len > 0) ? frames.len : 1
}
fn sprite_frame(dict sprites, int anim, int frame) dict {
   def frames = is_dict(sprites.get(anim_key(anim), {})) ? sprites.get(anim_key(anim), {}).get("frames", []) : []
   if(!is_list(frames) || frames.len <= 0){ return {} }
   def fr = frames.get(frame % frames.len, {})
   is_dict(fr) ? fr : {}
}
fn update_anim_frame(dict sprites, int anim, int frame, f64 counter, f64 duration, f64 dt, bool changed) list {
   if(changed){ return [0, 0.0] }
   def frames = frame_count(sprites, anim)
   if(frames <= 1){ return [frame, counter] }
   counter += dt
   if(counter >= duration){ frame = (frame + 1) % frames counter = 0.0 }
   [frame, counter]
}

fn screen(f64 x, f64 y, f64 cam_x, f64 cam_y, f64 sw, f64 sh) list { [x - cam_x + sw * 0.5, y - cam_y + sh * 0.5] }
fn draw_checker(list cache, f64 cam_x, f64 cam_y, f64 sw, f64 sh) any {
   def world_left, world_top = cam_x - sw * 0.5, cam_y - sh * 0.5
   ui_batch.static_checker(cache, world_left, world_top, sw, sh, CHECKED_CELL, COLOR_TILE_A)
}

fn draw_crosshair(f64 sw, f64 sh) int {
   def cx, cy = sw * 0.5, sh * 0.5
   line(cx - 12.0, cy, cx - 4.0, cy, 1.0, COLOR_TILE_LINE)
   line(cx + 4.0, cy, cx + 12.0, cy, 1.0, COLOR_TILE_LINE)
   line(cx, cy - 12.0, cx, cy - 4.0, 1.0, COLOR_TILE_LINE)
   line(cx, cy + 4.0, cx, cy + 12.0, 1.0, COLOR_TILE_LINE)
}

fn draw_player(dict sprites, int frame, f64 px, f64 py, f64 cam_x, f64 cam_y, f64 sw, f64 sh, int anim, bool flipped, f64 rotation) int {
   def fr = sprite_frame(sprites, anim, frame)
   if(!is_dict(fr) || int(fr.get("count", 0)) <= 0){ return 0 }
   def pos = screen(px, py, cam_x, cam_y, sw, sh)
   def cx, cy = float(pos.get(0, sw * 0.5)), float(pos.get(1, sh * 0.5))

   def tex = int(fr.get("tex", 0))
   if(tex > 0){
      def w = float(fr.get("w", 0)) * float(fr.get("scale", SPRITE_SCALE))
      def h = float(fr.get("h", 0)) * float(fr.get("scale", SPRITE_SCALE))
      if(anim_flip(anim, flipped)){
         gfx.draw_rect_tex_uv_rot(cx, cy, w, h, rotation, tex, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0)
      } else {
         gfx.draw_rect_tex_uv_rot(cx, cy, w, h, rotation, tex, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)
      }
      return 0
   }

   ui_batch.draw_mesh(fr, cx, cy, rotation, anim_flip(anim, flipped))
   0
}

fn draw_hud(dict fonts, f64 px, f64 py, f64 speed, int anim, int frame, int fps, f64 sw, f64 sh) int {
   def title, hud, small = i(fonts, "title", 0), i(fonts, "hud", 0), i(fonts, "small", 0)
   text(title, "Nygame", 12.0, 34.0, COLOR_TEXT)
   text(small, "WASD/arrows move  shift sprint  esc quit", 12.0, 58.0, COLOR_DIM)
   right_text(hud, to_str(fps) + " fps", sw - 12.0, 10.0, COLOR_ACCENT)
   text(hud, "x=" + to_str(int(px)) + " y=" + to_str(int(py)), 12.0, sh - 70.0, COLOR_TEXT)
   text(hud, "state=" + anim_name(anim) + " speed=" + to_str(int(speed)), 12.0, sh - 48.0, COLOR_ACCENT)
   text(hud, "frame=" + to_str(frame), 12.0, sh - 26.0, COLOR_DIM)
}

fn draw_scene(dict fonts, dict sprites, list checker_cache, int frame, bool flipped, f64 px, f64 py, f64 cam_x, f64 cam_y, f64 sw, f64 sh, int anim, f64 rotation, f64 step, int fps) any {
   def checker = draw_checker(checker_cache, cam_x, cam_y, sw, sh)
   gfx.set_ortho_2d(0.0, sw, 0.0, sh)
   draw_crosshair(sw, sh)
   draw_player(sprites, frame, px, py, cam_x, cam_y, sw, sh, anim, flipped, rotation)
   draw_hud(fonts, px, py, step, anim, frame, fps, sw, sh)
   checker
}

fn should_stop(dict cfg, int frames, f64 elapsed) bool {
   !b(cfg, "interactive", true)
   && ((i(cfg, "max_frames", 0) > 0 && frames >= i(cfg, "max_frames", 0))
      || (f(cfg, "max_seconds", 0.0) > 0.0 && elapsed >= f(cfg, "max_seconds", 0.0)))
}

fn dump_pre(dict cfg, bool done, int frames) int {
   if(b(cfg, "dump", false) && !done && frames + 1 >= i(cfg, "dump_frame", 4)){ gfx.request_frame_capture() }
   0
}

fn dump_post(dict cfg, bool done, int frames, any win) bool {
   if(!b(cfg, "dump", false) || done || frames < i(cfg, "dump_frame", 4)){ return done }
   def path = ui_dump.auto_dump_path(to_str(cfg.get("dump_path", "nygame_frame.png")))
   if(gfx.snapshot(path)){
      print("nygame: frame dump -> " + path)
      if(b(cfg, "dump_exit", false)){ window.set_should_close(win, true) }
      return true
   }
   false
}

fn run(dict cfg) int {
   def win = open_window(cfg)
   if(!win){ print("nygame: window init failed") return 1 }
   def root = to_str(cfg.get("asset_root", "."))
   def font_map = fonts(root)
   mut sprites = {}
   mut sprites_ready = false
   mut checker_cache = [0, 0, 0, 0, 0, 0, 0, 0, 0]
   mut running, dump_done = true, false
   mut fps_state = ui_runtime.fps_begin()
   mut fps, frames, elapsed = 0, 0, 0.0
   mut px, py, cam_x, cam_y = 0.0, 0.0, 0.0, 0.0
   mut flipped, last_idle, anim, prev_anim = true, ANIM_IDLE_LEFT, ANIM_IDLE_LEFT, ANIM_IDLE_LEFT
   mut speed, frame_duration, frame_counter, anim_frame = BASE_SPEED, 0.25, 0.0, 0
   mut rotation = 0.0
   while(running){
      if(ui_runtime.step(win)){ break }
      dump_pre(cfg, dump_done, frames)
      if(!gfx.begin_frame_clear([0.0, 0.0, 0.0, 1.0])){ continue }
      if(!sprites_ready){ sprites = load_sprites(root) sprites_ready = true }
      def raw_dt = gfx.get_delta_time()
      def dt = math.min(math.max(raw_dt, 1.0 / 240.0), 1.0 / 20.0)
      def fb = framebuffer(win, cfg)
      def sw, sh = float(fb.get(0, 1920)), float(fb.get(1, 1080))
      if(window.key_pressed(win, key.KEY_ESCAPE) || window.key_pressed(win, key.KEY_Q)){ window.set_should_close(win, true) running = false }
      prev_anim = anim
      def fast = window.key_down(win, key.KEY_LEFT_SHIFT) || window.key_down(win, key.KEY_RIGHT_SHIFT)
      speed = BASE_SPEED * (fast ? SPRINT_MULT : 1.0)
      frame_duration = fast ? 0.125 : 0.25
      def axis = input_axis(win, b(cfg, "demo_diagonal", false))
      def axis_x, axis_y = int(axis.get(0, 0)), int(axis.get(1, 0))
      def diagonal = axis_x != 0 && axis_y != 0
      def move_step = speed * (diagonal ? 0.7071067811865476 : 1.0)
      px += float(axis_x) * move_step * dt
      py += float(axis_y) * move_step * dt
      def motion = input_anim(axis_x, axis_y, last_idle, flipped)
      anim, last_idle, flipped = int(motion.get(0, ANIM_IDLE_LEFT)), int(motion.get(1, ANIM_IDLE_LEFT)), bool(motion.get(2, true))
      def frame_state = update_anim_frame(sprites, anim, anim_frame, frame_counter, frame_duration, dt, prev_anim != anim)
      anim_frame, frame_counter = int(frame_state.get(0, 0)), float(frame_state.get(1, 0.0))
      rotation = move_rotation(rotation, dt, axis_x, axis_y)
      def camera = update_camera(cam_x, cam_y, px, py, dt)
      cam_x, cam_y = float(camera.get(0, 0.0)), float(camera.get(1, 0.0))
      elapsed += raw_dt > 0.00001 ? raw_dt : dt
      frames += 1
      fps_state = ui_runtime.fps_tick(fps_state, raw_dt > 0.00001 ? raw_dt : dt)
      fps = ui_runtime.fps_current(fps_state, raw_dt > 0.00001 ? raw_dt : dt)
      if(should_stop(cfg, frames, elapsed)){ running = false }
      checker_cache = draw_scene(font_map, sprites, checker_cache, anim_frame, flipped, px, py, cam_x, cam_y, sw, sh, anim, rotation, speed, fps)
      gfx.end_frame()
      dump_done = dump_post(cfg, dump_done, frames, win)
      if(dump_done && b(cfg, "dump_exit", false)){ running = false }
   }
   ui_runtime.fps_finish("nygame", fps_state)
   destroy_sprites(sprites)
   ui_batch.release_static_checker(checker_cache)
   gfx.close_window()
   0
}

run(config(cli.args()))
