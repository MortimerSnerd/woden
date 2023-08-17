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
import game.prompts
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

    cur_action_prompt = nil :: player_prompt<action_pair>


    // We maintain our own list of checked keys instead of using the core.bindings
    // one because context sensitive bump actions are more complicated than static
    // action -> does_something mappings.
    valid_keys = [] :: kvpair<string, string>   // kb_action, action desc

    private def set_prompt(p):
        assert not cur_action_prompt
        cur_action_prompt = p
        //activate_mode(p)

    private def key_checked(action: string, desc: string = ""):
        push(valid_keys, kvpair<string,string>{action, if desc == "": action else: desc})

    private def on_key(test: key_tests, action: string, body):
        key_checked(action)
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

        on_key(key_went_down, kb_quit):
            return ir_finished

        if cur_action_prompt:
            let rc = cur_action_prompt.update(d_t)
            if rc == ir_finished:
                if cur_action_prompt.result:
                    cur_action_prompt.result.payload.desc.execute(cur_action_prompt.result.payload.st)
                    turn_taken = true
                cur_action_prompt = nil
            else:
                return ir_ok


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

        struct key_choice:
            key: key_desc   // Key to be pressed to take the action
            act: string     // Action to be checked.  Can differ from the action_state.kb_action in bump case
            ap: action_pair // Action pair from a possible move query


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


        let choices = []
        let bnd = current_bindings()
        guard bnd:
            return ir_ok

        // Accumulate any object interactions that are in a direction
        // we can't move.  For these cases a context sensitive move can work.
        for(actions) p:
            if p.desc is object_interaction and p.st.what:
                let odir = p.st.what.cc - player.cc
                let diri = find(valid_dirs): _ == odir
                if diri < 0:
                    let actn = dir_to_action[find(all_dirs): _ == odir]
                    let kdesc = bnd.key_for_action(actn)
                    guard kdesc
                    push(choices, key_choice{kdesc, actn, p})
                        

        // Accumulate rest of the actions.
        for(actions) ap:
            let kdesc = bnd.key_for_action(ap.st.kb_action)
            guard kdesc
            push(choices, key_choice{kdesc, ap.st.kb_action, ap})
    
        // Group by actual key pressed, so we can see when
        // to prompt when there is more than one choice for a key.
        qsort_in_place(choices) a, b: a.key < b.key
        for_groups_in(choices, fn(a,b): a.key.same_as(b.key)) fst, last: 
            if fst == last:
                let ch = choices[fst]
                key_checked(ch.act, ch.ap.st.kb_action)
                when_binding(key_went_down, ch.act):
                    ch.ap.desc.execute(ch.ap.st)
                    turn_taken = true
            else:
                key_checked(choices[fst].act, choices[fst].ap.st.kb_action + " (prompt)")
                when_binding(key_went_down, choices[fst].act):
                    // Characterize choices to pick appropriate prompt.
                    var all_interactions = true
                    var all_neighbors = true
                    for_range_incl(fst, last) i:
                        let act = choices[i].ap.desc
                        switch act:
                            case target_action:
                                all_interactions = all_interactions and act is object_interaction
                                let what = choices[i].ap.st.what
                                all_neighbors = all_neighbors and what and what.cc.is_neighbor_of(player.cc)
                            case location_action:
                                all_interactions = false
                                all_neighbors = all_neighbors and choices[i].ap.st.where.is_neighbor_of(player.cc)
                            case self_action:
                                all_interactions = false
                                all_neighbors = false

                    if all_neighbors:
                        // Can just prompt for a direction
                        let pc = []
                        for_range_incl(fst, last) i:
                            let ch = choices[i]
                            guard ch.ap.st.what
                            let dirv = ch.ap.st.what.cc - player.cc
                            let diract = dir_to_action[find(all_dirs): _ == dirv]
                            let dirkey = bnd.key_for_action(diract) 
                            guard dirkey
                            push(pc, prompt_choice<action_pair>{
                                dirkey, ch.ap
                            })
                        set_prompt(direction_prompt<action_pair>(pc))
                    else:
                        fatal("no prompt picked for {fst} {choices}")
                            
            if turn_taken:
                return from for_groups_in



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
        guard keys and length(valid_keys) > 0
        qsort_in_place(valid_keys) a, b: b.value < a.value
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

        if cur_action_prompt:
            cur_action_prompt.render()

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

            var snd_door = false
            let d2pos = int2{2, 4}
            lev.for_objects_at(d2pos) o:
                if o.type_name() == "door":
                    snd_door = true

            if not snd_door:
                let err, d2 = create_object("door", d2pos, [
                    mixin_desc{
                        name: "door", 
                        pnames: ["open", "closed", "orient"],
                        pvals: [ "dev/door1ho.png", "dev/door1hc.png", "h"]
                    }])
                if d2:
                    lev.add_object(d2)
                else:
                    print("create door 2 {err}")

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
