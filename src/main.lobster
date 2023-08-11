import color
import texture

import core.bindings
import core.logging
import core.perf

import data.binary
import game.allobjects
import game.blocks
import game.defs
import game.draw
import game.editor
import game.grids
import game.mode
import game.objects
import game.propmap
import game.state

class test_mode: game_mode
    lev: grid_level
    top_left = int2_0
    scale = 2
    player = nil :: object_instance
    first_frame = false
    last_winsize = int2_0

    def update(d_t: float) -> input_result:
        guard player:
            return ir_ok
        bindings_begin_frame()
        PERF.start("main update")
        var turn_taken = false
        let wsz = gl_window_size()

        if wsz != last_winsize:
            // Trigger redraw of playfield, including masks.
            turn_taken = true
            last_winsize = wsz

        if first_frame:
            turn_taken = true
            first_frame = false

        when_binding(key_went_down, kb_debugger):
            breakpoint()
        when_binding(key_went_down, kb_right):
            player.cc += int2_x
            turn_taken = true
        when_binding(key_went_down, kb_left):
            player.cc -= int2_x
            turn_taken = true
        when_binding(key_went_down, kb_up):
            player.cc -= int2_y
            turn_taken = true
        when_binding(key_went_down, kb_down):
            player.cc += int2_y
            turn_taken = true
        when_binding(key_went_down, kb_editor):
            activate_mode(editor_mode{lev, top_left})

        when_binding(key_went_down, kb_increase_scale):
            scale += 1
            turn_taken = true
        if scale > 1:
            when_binding(key_went_down, kb_decrease_scale):
                scale = max(1, scale-1)
                turn_taken = true

        if gl_button("space") == 1:
            lev.floor.set_toc_index(top_left+int2_1*4, 0)

        // debuggery
        for_objects_in_reach_of(player) o:
            var act = ""
            if o.supports_interaction(player, "open"):
                when_binding(key_went_down, kb_open):
                    act = "open"
            elif o.supports_interaction(player, "close"):
                when_binding(key_went_down, kb_close):
                    act = "close"

            if act != "":
                let suc, _dur, err = o.interact(player, act)
                if not suc:
                    print("{act}: {err}")
                turn_taken = true
                return from for_objects_in_reach_of


        when_binding(key_went_down, kb_quit):
            return ir_finished

        let view = screen_view_bounds(top_left, scale)
        lev.update(d_t, turn_taken, player.cc, 30, view)

        PERF.stop()
        return ir_ok


    def write_control_help():
        gl_ortho()
        gl_color(color_white)
        gl_set_shader("color")
        gl_blend(blend_alpha)
        gl_set_font_name("data/fonts/Droid_Sans/DroidSans.ttf")
        gl_set_font_size(16)
        let cdim = float(gl_text_size("W"))
        let vspace = 4.0
        var y = float(gl_window_size().y) - cdim.y - vspace

        for_tested_bindings() act, _test, desc:
            gl_translate(float2{cdim.x*2.0, y}):
                gl_text("{desc.to_string()} - {act}")
                y -= vspace + cdim.y


    def render():
        guard player
        PERF.start("main render")
        gl_clear(color{1.0, 1.0, 1.0, 0.0})
        let wsz = gl_window_size()
        top_left = player.cc - screen_view_size(scale)/2
        let view = screen_view_bounds(top_left, scale)

        draw_ortho(wsz/scale)
        gl_set_shader("textured_color")
        gl_translate(-float(top_left*lev.floor.pxsize)):
            lev.render(view)

        write_control_help()
        PERF.stop()

    def on_activate(reactivation: bool):
        if reactivation:
            pass()
        else:
            let keys = binding_set{allow_duplicates: true}
            keys.bind(kb_left, key_desc{0, "a"})
            keys.bind(kb_right, key_desc{0, "d"})
            keys.bind(kb_up, key_desc{0, "w"})
            keys.bind(kb_down, key_desc{0, "s"})
            keys.bind(kb_quit, key_desc{mod_control, "x"})
            keys.bind(kb_editor, key_desc{0, "f1"})
            keys.bind(kb_increase_scale, key_desc{0, "="})
            keys.bind(kb_decrease_scale, key_desc{0, "-"})
            keys.bind(kb_debugger, key_desc{mod_control, "b"})
            keys.bind(kb_open, key_desc{0, "o"})
            keys.bind(kb_close, key_desc{0, "o"})
            
            push_bindings(keys)

            let rerr, ll = load_grid_level("dist/backup.lv")
            if rerr:
                print(rerr)
            else:
                lev = ll
                current_level = lev
            first_frame = true

            if length(lev.objects) == 0:
                let err, dr = create_object("door", int2_1*3, [])
                if dr:
                    lev.add_object(dr)
                else:
                    print("BALLS {err}")

            // Pull player saved with level.
            if not player:
                for_objects_of_type("player") o:
                    player = o
                    return from for_objects_of_type

            // None found, create a new object for the player.
            if not player:
                let err, p = create_object("player", int2_1*2, [])
                if p:
                    player = p
                    lev.add_object(player)
                else:
                    print("can\'t create player? {err}")

            //let lerr, lant = create_object("lantern", int2{5, 4}, [])
            //if lant:
                ////lev.add_object(lant)
            //else:
                //print("mi lights {lerr}")

    def on_deactivate(removed: bool):
        if removed:
            pop_bindings()

def go():
    fatal(gl_window("Eat Crap", 1024, 768))
    fatal(gl_load_materials("dist/woden.materials"))
    //LoggingLevel |= Timings
    im_init()
    fatal(load_blockdefs())
    fatal(init_objects())
    //TODO wall /2 or /4 from floor/mob size?
    let tm = test_mode{mk_grid_level(int2_1*floor_pxsize)}
    activate_mode(tm)

    while gl_frame() and has_active_mode():
        update_active_mode(gl_delta_time())
        render_active_mode()

go()
