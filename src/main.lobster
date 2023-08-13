import color
import texture

import core.bindings
import core.logging
import core.perf

import data.binary
import game.actions
import game.actions.query
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

    // We maintain our own list of checked keys instead of using the core.bindings
    // one because context sensitive bump actions are more complicated than static
    // action -> does_something mappings.
    valid_keys = [] :: kvpair<string, string>   // kb_action, action desc

    private def key_checked(action: string, desc: string = ""):
        push(valid_keys, kvpair<string,string>{action, if desc == "": action else: desc})

    private def on_key(test: key_tests, action: string, body):
        key_checked(action)
        when_binding(test, action, body)

    private def on_bump_key(test: key_tests, action: string, desc: string, body):
        key_checked(action, desc)
        when_binding(test, action, body)

    def update(d_t: float) -> input_result:
        guard player:
            return ir_ok
        bindings_begin_frame()
        valid_keys = []
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

        on_key(key_went_down, kb_debugger):
            breakpoint()

        on_key(key_went_down, kb_editor):
            activate_mode(editor_mode{lev, top_left})

        on_key(key_went_down, kb_increase_scale):
            scale += 1
            turn_taken = true

        if scale > 1:
            on_key(key_went_down, kb_decrease_scale):
                scale = max(1, scale-1)
                turn_taken = true

        if gl_button("space") == 1:
            lev.floor.set_toc_index(top_left+int2_1*4, 0)


        // Check actions for valid moves.  Invalid move directions
        // are candidates for context sensitive bump actions with the 
        // direction keys.
        let valid_dirs = []
        let actions = []
        for_possible_actions(player) desc, st:
            guard st.kb_action != ""
            if desc is move_action:
                push(valid_dirs, st.where - player.cc)
            push(actions, action_pair{desc, copy(st)})

        // Accumulate any object interactions that are in a direction
        // we can't move.
        let poss_bumps = []
        for(actions) p:
            if p.desc is object_interaction and p.st.what:
                let odir = p.st.what.cc - player.cc
                if (find(valid_dirs): _ == odir) < 0:
                    let ix = find_or_create<int2,[action_pair]>(poss_bumps, odir):
                        []
                    push(poss_bumps[ix].value, p)

        // Process any bump actions first.
        for(poss_bumps) bp:
            //TODO priority scheme when there is more than once choice.  We just pick first here.
            let act = dir_to_action[find(all_dirs): _ == bp.key]
            on_bump_key(key_went_down, act, bp.value[0].desc.short_desc):
                bp.value[0].desc.execute(bp.value[0].st)
                turn_taken = true
            if turn_taken:
                break
                
        // Handle rest of actions normally.
        if not turn_taken:
            for(actions) p:
                on_key(key_went_down, p.st.kb_action):
                    p.desc.execute(p.st)
                    turn_taken = true
                if turn_taken:
                    break

        on_key(key_went_down, kb_quit):
            return ir_finished

        let view = screen_view_bounds(top_left, scale)
        lev.update(d_t, turn_taken, player.cc, 30, view)

        PERF.stop()
        return ir_ok

    def write_possible_controls():
        gl_ortho()
        gl_color(color_white)
        gl_set_shader("color")
        gl_blend(blend_alpha)
        gl_set_font_name("data/fonts/Droid_Sans/DroidSans.ttf")
        gl_set_font_size(16)
        let cdim = float(gl_text_size("W"))
        let vspace = 4.0
        var y = float(gl_window_size().y) - cdim.y - vspace

        let keys = current_bindings()
        guard keys
        for(valid_keys) p:
            let desc = keys.key_for_action(p.key)
            guard desc
            gl_translate(float2{cdim.x*2.0, y}):
                gl_text("{desc.to_string()} - {p.value}")
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

        write_possible_controls()
        PERF.stop()

    def on_activate(reactivation: bool):
        if reactivation:
            pass()
        else:
            let keys = binding_set{allow_duplicates: true}
            keys.bind(kb_quit, key_desc{mod_control, "x"})
            keys.bind(kb_editor, key_desc{0, "f1"})
            keys.bind(kb_increase_scale, key_desc{0, "="})
            keys.bind(kb_decrease_scale, key_desc{0, "-"})
            keys.bind(kb_debugger, key_desc{mod_control, "b"})
            keys.bind(kb_open, key_desc{0, "o"})
            keys.bind(kb_close, key_desc{0, "o"})
            // For debugging, using rogue vikeys for movement
            keys.bind(kb_north, key_desc{0, "k"}) 
            keys.bind(kb_south, key_desc{0, "j"}) 
            keys.bind(kb_east, key_desc{0, "l"}) 
            keys.bind(kb_west, key_desc{0, "h"}) 
            keys.bind(kb_northeast, key_desc{0, "u"}) 
            keys.bind(kb_southeast, key_desc{0, "n"}) 
            keys.bind(kb_southwest, key_desc{0, "b"}) 
            keys.bind(kb_northwest, key_desc{0, "y"}) 
            keys.bind(kb_turn_on, key_desc{0, "a"})
            keys.bind(kb_turn_off, key_desc{0, "a"})
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
