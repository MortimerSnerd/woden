// Some top level constants and utility functions.
import core.aabb
import core.perf
import data.binary

// 
// Action names for key bindings
//

// Game and common
let kb_editor = "start editor"
let kb_left = "move left"
let kb_right = "move right"
let kb_up = "move up"
let kb_down = "move down"
let kb_quit = "quit"
let kb_increase_scale = "increase scale"
let kb_decrease_scale = "decrease scale"
let kb_debugger = "start debugger"
let kb_open = "open"
let kb_close = "close"

// Editor
let kb_pick_block = "pick block"
let kb_switch_layer = "switch layer"
let kb_yank_block = "yank block"
let kb_escapu = "cancel selections"
let kb_fill_empties = "fill empty cells"
let kb_save = "save"
let kb_revert = "revert to last save"
let kb_toggle_lighting = "toggle lighting"
let kb_increase_light = "increase light"
let kb_decrease_light = "decrease light"

// Layer render depths
let floor_render_layer = 0.0
let obj_render_layer = 0.5
let wall_render_layer = 1.0
let dyn_obj_render_layer = 1.5
let seen_mask_layer = 2.0

// pixel size of floor tiles
let floor_pxsize = 32

// Wall layers have smaller cell pixel sizes.  This is the factor of size
// difference for a single dimension.
let layer_size_factor = 4

let DEBUG_BUILD=true

// Stopwatch used for timings througout.
let PERF = stopwatch{}

// View size in floor coordinates given current screen resolution.
def screen_view_size(scale: int = 1) -> int2:
    return gl_window_size()/(floor_pxsize*scale)

// Creates a cell view rect for the given top left position and the current
// screen size.
def screen_view_bounds(top_left: int2, scale: int = 1) -> aabb2i:
    return aabb2i{top_left, top_left + screen_view_size(scale)}

// Sets the font used for editor ui
def set_ui_editor_font(header = false):
    gl_set_font_name("data/fonts/Zapato/greensboro.ttf")
    gl_set_font_size(if header: 28 else: 20, 1.0)

// Assertion that pops a breakpoint if DEBUG_BUILD
def gassert(cond):
    if not cond:
        if DEBUG_BUILD:
            breakpoint()
        else:
            assert cond

def serialize_bb2i(D: binary_editor, bb):
    D.write_vertex2i(bb.mins)
    D.write_vertex2i(bb.maxs)

def deserialize_bb2i(D: binary_editor) -> aabb2i:
    let mins = D.read_vertex2i()
    let maxs = D.read_vertex2i()
    return aabb2i{mins, maxs}
