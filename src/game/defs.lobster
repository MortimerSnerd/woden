// Some top level constants and utility functions.
import color
import core.aabb
import core.bindings
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
let kb_turn_on = "turn on"
let kb_turn_off = "turn off"

//TODO use these for movement, not up, down, left,right
let kb_north = "move north"
let kb_south = "move south"
let kb_east = "move east"
let kb_west = "move west"
let kb_northeast = "move northeast"
let kb_southeast = "move southeast"
let kb_southwest = "move southwest"
let kb_northwest = "move northwest"

let movement_actions = [
    kb_north,
    kb_south,
    kb_east,
    kb_west,
    kb_northeast,
    kb_southeast,
    kb_southwest,
    kb_northwest
]

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

// Colors used by ui elements
let prompt_bg = color{0.2, 0.2, 0.2, 1.0}
let prompt_fg = color_white

// Layer render depths
let floor_render_layer = 0.0
let obj_render_layer = 0.5
let wall_render_layer = 1.0
let dyn_obj_render_layer = 1.5
let seen_mask_layer = 2.0

// Standard interaction names
let ia_turn_on = "turn on"
let ia_turn_off = "turn off"

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
    return gl.window_size()/(floor_pxsize*scale)

// Creates a cell view rect for the given top left position and the current
// screen size.
def screen_view_bounds(top_left: int2, scale: int = 1) -> aabb2i:
    return aabb2i{top_left, top_left + screen_view_size(scale)}

// Sets the font used for editor ui
def set_ui_editor_font(header = false):
    gl.set_font_name("data/fonts/Zapato/greensboro.ttf")
    gl.set_font_size(if header: 28 else: 20, 1.0)

// Sets the font used for player prompts
def set_prompt_font():
    gl.set_font_name("data/fonts/Droid_Sans/DroidSans.ttf")
    gl.set_font_size(18)

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


// Helper function for drawing simple binding help using core.bindings features.
def write_control_help():
    gl.ortho()
    gl.color(color_white)
    gl.set_shader("color")
    gl.blend(blend_alpha)
    set_prompt_font()
    let cdim = float(gl.text_size("W"))
    let vspace = 4.0
    var y = float(gl.window_size().y) - cdim.y - vspace

    for_tested_bindings() act, _test, desc:
        gl.translate(float2{cdim.x*2.0, y}):
            gl.text("{desc.to_string()} - {act}")
            y -= vspace + cdim.y


