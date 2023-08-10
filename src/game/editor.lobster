// simple editor for levels.
import color
import imgui
import gl

import core.algs
import core.bindings
import game.grids
import game.mode

//TODO add functionality to set light levels for cells

private let cell_pick_margins = 10

private def draw_bb_outline(a, thick):
    let mins = float(a.mins)
    let maxs = float(a.maxs)
    gl_line(mins, float2{maxs.x, mins.y}, thick)
    gl_line(mins, float2{mins.x, maxs.y}, thick)
    gl_line(maxs, float2{maxs.x, mins.y}, thick)
    gl_line(maxs, float2{mins.x, maxs.y}, thick)

enum edit_mode:
    em_change_floor, em_change_walls

class editor_mode: game_mode
    lev: grid_level
    top_left: int2

    mode = em_change_floor

    // toc index for item we want to place
    cur_cell = 0

    // True if the block selection screen is up.
    selecting_block = false
    // bounding boxes for blocks, and corresponding block index.
    select_bbs = [] :: kvpair<aabb2i,int>

    // Block selection bounding box
    block_selection = aabb2i{int2_0, -int2_1}

    scale = 2

    map_file = "dist/backup.lv"

    // toc ixs for a stamp, and its dimensions.
    stamp_ixs = [] :: int
    stamp_dims = int2_0

    private def get_toc():
        return switch mode:
            case em_change_floor:
                lev.floor.toc
            default:
                lev.wall.toc

    private def cur_layer():
        if mode == em_change_floor:
            return lev.floor
        else:
            return lev.wall

    private def cell_pxsize():
        return switch mode:
            case em_change_floor:
                lev.floor.pxsize
            default:
                lev.wall.pxsize

    private def screen_to_cell(p: int2, pxsize: int2) -> int2:
        // NB floor_pxsize - account for fact top_left is always measured
        //    in floor cell coordinates.
        return top_left*(floor_pxsize/pxsize) + p/(pxsize*scale)

    private def cell_tl_to_screen(cc: int2, pxsize: int2) -> int2:
        return (cc - top_left*(floor_pxsize/pxsize)) * pxsize*scale

    private def screen_to_cell(p: int2) -> int2:
        return screen_to_cell(p, cell_pxsize())

    private def cell_tl_to_screen(cc: int2) -> int2:
        return cell_tl_to_screen(cc, cell_pxsize())

    def on_activate(reactivation: bool):
        if not reactivation:
            let keys = binding_set{}
            keys.bind(kb_quit, key_desc{mod_control, "x"})
            keys.bind(kb_escapu, key_desc{0, "escape"})
            keys.bind(kb_pick_block, key_desc{0, "b"})
            keys.bind(kb_left, key_desc{0, "a"})
            keys.bind(kb_right, key_desc{0, "d"})
            keys.bind(kb_up, key_desc{0, "w"})
            keys.bind(kb_down, key_desc{0, "s"})
            keys.bind(kb_switch_layer, key_desc{0, "tab"})
            keys.bind(kb_increase_scale, key_desc{0, "="})
            keys.bind(kb_decrease_scale, key_desc{0, "-"})
            keys.bind(kb_yank_block, key_desc{0, "y"})
            keys.bind(kb_fill_empties, key_desc{0, "f"})
            keys.bind(kb_save, key_desc{mod_control, "s"})
            keys.bind(kb_revert, key_desc{mod_control, "r"})
            keys.bind(kb_toggle_lighting, key_desc{0, "l"})
            keys.bind(kb_increase_light, key_desc{0, "]"})
            keys.bind(kb_decrease_light, key_desc{0, "["})
            push_bindings(keys)
            lev.editing = true
            lev.light_everything = true
            lev.i_see_all()

    private def highlight_cell_under_cursor():
        let mp = gl_mouse_pos(0)
        let tl_s = cell_tl_to_screen(screen_to_cell(mp))
        let bb = aabb2i{tl_s, tl_s + cell_pxsize()*scale}
        gl_color(color_white):
            draw_bb_outline(bb, 1.0)
        if mode == em_change_walls:
            // outline floor block as well to make it easy to keep things aligned.
            let ftl_s = cell_tl_to_screen(screen_to_cell(mp, lev.floor.pxsize), 
                                          lev.floor.pxsize)
            let fbb = aabb2i{ftl_s, ftl_s + lev.floor.pxsize*scale}
            gl_color(color_blue):
                draw_bb_outline(fbb, 1.0)

    private def for_stamp_cells(body):
        if length(stamp_ixs) > 0:
            var i = 0
            for(stamp_dims.y) y:
                for(stamp_dims.x) x:
                    body(int2{x,y}, stamp_ixs[i++])
             
    private def render_cur_stamp():
        if length(stamp_ixs) > 0:
            let tl = gl_mouse_pos(0)/scale - cell_pxsize()/2
            for_stamp_cells() cc, ti:
                if ti > 0:
                    draw_image(get_toc().block_index(ti),
                               tl + cc*cell_pxsize(), 10.0)
        else:
           if cur_cell > 0:
            let blk = get_toc().block_index(cur_cell)
            if blk >= 0:
                draw_image(blk, gl_mouse_pos(0)/scale - cell_pxsize()/2, 10.0)

    def on_deactivate(removed: bool):
        if removed:
            pop_bindings()
            lev.editing = false
            lev.light_everything = false
            lev.clear_seen()

    private def split4_file_prefix(bi):
        guard bi >= 0:  
            return ""
        let img = blk_img_name[bi]
        let i = find_string(img, "|")

        if i > 0:
            return substring(blk_img_name[bi], 0, i)
        return ""

    private def mk_stamp_from_split4(bi: int):
        let prefix = split4_file_prefix(bi)
        guard prefix != ""
        
        var i = bi
        while i >= 0 and blk_img_name[i].begins_with(prefix):
            i--

        stamp_ixs = []
        stamp_dims = int2_1*4
        for(16):
            push(stamp_ixs, get_toc().assign_block(++i))

    private def maybe_pick_block():
        let p = gl_mouse_pos(0)
        for(select_bbs) bb:
            if bb.key.contains(p):
                if gl_button("left shift") > 0:
                    mk_stamp_from_split4(bb.value)
                else:
                    cur_cell = get_toc().assign_block(bb.value)
                    stamp_ixs = []
                selecting_block = false
                
                return

    private def change_lm_val(amt):
        let cc = screen_to_cell(gl_mouse_pos(0))
        if block_selection.is_degenerate() or not block_selection.contains(cc):
            lev.lightmap.adj_byte(cc, amt)
        else:
            block_selection.for_allxy() bc:
                lev.lightmap.adj_byte(bc, amt)


    def update(d_t: float) -> input_result:
        let mp = gl_mouse_pos(0)
        let m1 = gl_button("mouse1")
        let m3 = gl_button("mouse3")

        if m1 == 1:
            if selecting_block:
                maybe_pick_block()
            else:
                if gl_button("left ctrl") > 0:
                    cur_cell = cur_layer().toc_ix_at(screen_to_cell(mp))
                else:
                    let act_cell = if gl_button("left shift") > 0: 0 else: cur_cell 
                    if act_cell >= 0:
                        let cc = screen_to_cell(mp)
                        if length(stamp_ixs) > 0:
                            for_stamp_cells() cstamp, ti:
                                cur_layer().set_toc_index(cc+cstamp, ti)
                        elif block_selection.is_degenerate() or not block_selection.contains(cc):
                            cur_layer().set_toc_index(cc, 
                                                      act_cell)
                        else:
                            cur_layer().set_toc_index(block_selection, act_cell)
        if m3 == 1:
            let cc = screen_to_cell(mp)
            block_selection = aabb2i{cc, cc}
        elif m3 > 0:
            let cc = screen_to_cell(mp)
            block_selection = aabb2i{block_selection.mins, cc}

        when_binding(key_went_down, kb_toggle_lighting):
            lev.light_everything = not lev.light_everything
            lev.masks_invalidated = true

        if mode == em_change_walls:
            when_binding(key_went_down, kb_increase_light):
                let amt = if gl_button("left shift") > 0: 50 else: 10
                change_lm_val(amt)
                lev.masks_invalidated = true

            when_binding(key_went_down, kb_decrease_light):
                let amt = -if gl_button("left shift") > 0: 50 else: 10
                change_lm_val(amt)
                lev.masks_invalidated = true

        when_binding(key_went_down, kb_save):
            lev.clear_seen()
            let err = save_grid_level(lev, map_file)
            if err:
                print("SAVE ERROR: {err}")

        when_binding(key_went_down, kb_revert):
            let err, ll = load_grid_level(map_file)
            if err:
                print("LOAD ERROR: {err}")
            else:
                lev = ll
                cur_cell = 0
                block_selection = aabb2i{int2_0, -int2_1}
                stamp_ixs = []
                //TODO how to communicate back to game mode,
                //  we're no longer sharing

        when_binding(key_went_down, kb_fill_empties):
            let cc = screen_to_cell(mp)
            if length(stamp_ixs) > 0:
                let ch = cur_layer().chunk_for_cell(cc)
                ch.bounds.for_allxy() p:
                    let tix = ch.toc_ix_at(p)
                    if tix == 0:
                        ch.set_toc_index(p, stamp_ixs[p.x%stamp_dims.x + (p.y%stamp_dims.y * stamp_dims.x)])
            elif cur_cell >= 0:
                let ch = cur_layer().chunk_for_cell(cc)
                ch.bounds.for_allxy() p:
                    let tix = ch.toc_ix_at(p)
                    if tix == 0:
                        ch.set_toc_index(p, cur_cell)
                
        when_binding(key_went_down, kb_escapu):
            if selecting_block:
                selecting_block = false
            elif not block_selection.is_degenerate():
                block_selection = aabb2i{int2_0, -int2_1}
            else:
                stamp_ixs = []

        when_binding(key_went_down, kb_quit):
            return ir_finished

        if not block_selection.is_degenerate():
            when_binding(key_went_down, kb_yank_block):
                stamp_ixs = []
                cur_layer().for_toc_ixs(block_selection) ti:
                    push(stamp_ixs, ti)
                stamp_dims = block_selection.extent()

        when_binding(key_went_down, kb_switch_layer):
            cur_cell = 0
            if mode == em_change_walls:
                mode = em_change_floor
            else:
                mode = em_change_walls

        when_binding(key_went_down, kb_pick_block):
            selecting_block = not selecting_block

        when_binding(key_went_down, kb_right):
            top_left += int2_x
        when_binding(key_went_down, kb_left):
            top_left -= int2_x
        when_binding(key_went_down, kb_up):
            top_left -= int2_y
        when_binding(key_went_down, kb_down):
            top_left += int2_y

        when_binding(key_went_down, kb_increase_scale):
            scale += 1
        when_binding(key_went_down, kb_decrease_scale):
            scale = max(1, scale-1)

        return ir_ok

    private def render_select():
        let w_sz = gl_window_size()
        gl_clear(color_black)
        gl_blend(blend_alpha)
        set_ui_editor_font(true)
        gl_text("Pick Block")

        draw_ortho(w_sz/scale)
        gl_set_shader("textured_color")
        gl_blend(blend_none)

        var y = gl_text_size("W").y + 10
        var x = cell_pick_margins

        let cur_pxsize = cell_pxsize()
        select_bbs = []
        draw_begin()
        for(blk_img_size) sz, bi:
            if cur_pxsize == sz:
                let tl = int2{x, y}
                let bb = aabb2i{tl, tl + sz*scale}
                push(select_bbs, kvpair<aabb2i,int>{bb, bi})
                draw_image(bi, tl/scale, 10.0)
                x += sz.x*scale + cell_pick_margins
                if (x+sz.x) >= w_sz.x:
                    x = cell_pick_margins
                    y += cell_pick_margins + sz.y*scale
        draw_finish()

    def render_ui_window():
        gl_set_shader("color")
        gl_ortho()
        gl_blend(blend_alpha)

        im_frame():
            im_window("Properties", 0):
                lev.lightmap.default_value = im_sliderint("ambient light", 
                                                           lev.lightmap.default_value,
                                                           0, 255)

    def render():
        if selecting_block:
            render_select()
        else:
            gl_clear(color_red)    
            let view = screen_view_bounds(top_left, scale)
            draw_ortho(gl_window_size()/scale)
            gl_set_shader("textured_color")
            gl_translate(-float(top_left*lev.floor.pxsize)):
                lev.render(view)
                gl_blend(blend_alpha)

            draw_begin()
            gl_set_shader("textured_color")
            render_cur_stamp()
            draw_finish()

            gl_set_shader("color")
            gl_ortho()
            gl_blend(blend_alpha)
            highlight_cell_under_cursor()

            if not block_selection.is_degenerate():
                gl_color(color_white):
                    let pbb = aabb2i{cell_tl_to_screen(block_selection.mins),
                                     cell_tl_to_screen(block_selection.maxs+1)}
                    draw_bb_outline(pbb, 1.0)

            set_ui_editor_font(true)

            var bn = ""
            if cur_cell > 0:
                bn = blk_img_name[get_toc().block_index(cur_cell)]
            gl_translate(float2_1*10.0):
                gl_text("{mode}     {bn}") 
    
            
            render_ui_window()
