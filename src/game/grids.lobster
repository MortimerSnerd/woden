// Grids we store level data into.
import core.algs
import core.aabb
import core.shadowcast
import data.binary
import data.meshbuilder
import data.textures
import game.blocks
import game.propmap
import game.draw
import game.lights
import game.objects



// Chunk size for viz propmap.  Pulled this value out of my ass, could be tuned.
private let viz_chunk_dims = int2_1*128

// Converts floor coord to top bounding box covering the contained wall coordinates.
def floor_coord_to_wall_area(cc: int2) -> aabb2i:
    let tl = cc*layer_size_factor
    return aabb2i{tl, tl + int2_1*layer_size_factor-1}

// Converts wall coordinate to coordinate of enclosing floor cell.
def wall_to_floor(wc: int2) -> int2:
    return wc/layer_size_factor

// Converts floor coordinate to coordinate of top left wall coordinate contained
// in that floor cell.
def floor_to_wall(cc: int2) -> int2:
    return cc*layer_size_factor

// Converts floor coordnate to the bottom right wall coordinate contained by the
// floor cell.
def floor_to_wall_br(cc: int2) -> int2:
    return floor_to_wall(cc) + int2_1*(layer_size_factor-1)

// converts floorbb to wall bb.
def floor_bb_to_wall(bb: aabb2i) -> aabb2i:
    return aabb2i{bb.mins*layer_size_factor, bb.maxs*layer_size_factor}

// Converts wall coordinate to absolute top left pixel coordinate.
def wall_to_px(wc: int2) -> int2:
    return wc*int2_1*floor_pxsize/layer_size_factor

def floor_to_px(cc: int2) -> int2:
    return cc*int2_1*floor_pxsize

private var stipple_texture = nil :: resource<texture>

private def get_stipple_texture() -> resource<texture>:
    if not stipple_texture:
        let colors = [float4{0.0, 0.0, 0.0, 0.7}, 
                      float4{0.0, 0.0, 0.0, 1.0}]
        let d = floor_pxsize / layer_size_factor
        let m = map(d): []
        for(m) rowarr, row:
            for(d) col:
                let ci = ((col&2) >> 1) 
                if row&2:
                    push(rowarr, colors[ci])
                else:
                    push(rowarr, colors[1-ci])
        stipple_texture = gl_create_texture(m, blocks_tx_format)

    guard stipple_texture:
        fatal("could not create stipple texture, I croak")
        return from program

    return stipple_texture

// Each grid can have 255 separate images it can reference. 
// This class keeps up with the mapping from image indices to 
// atlas handles for the associated image.
class grid_toc:
    // From grid index to block index that actually has block info and subimage
    // information.  0 is always treated as empty space, so we only hold entries
    // for 1-255.  If block_ixs[x]
    // < 0, that toc entry hasn't been set yet.
    block_ixs = map(255): -1

    // Finds a toc slot for a block index, and returns the toc index.  If the block 
    // index is already in the toc, that entry is returned.  Returns -1 if the 
    // toc is already full.
    def assign_block(blk_index: int) -> int:
        let ti = find(block_ixs): _ == blk_index
        if ti >= 0:
            return ti+1
        let free = find(block_ixs): _ == -1
        if free >= 0:
            block_ixs[free] = blk_index
            return free+1
        return -1

    // Returns the block index for the given toc index.
    def block_index(toc_ix: int):
        return block_ixs[toc_ix-1]

    def serialize(D: binary_editor):
        D.write_string("toc0") // version 0
        // Write index, block index pairs for any populated slots, 
        // terminate with 0 in index position.
        for(block_ixs) bi, i:
            if bi != -1:
                D.write_byte(i+1)
                D.write_int32(bi)
        D.write_byte(0)
                
    def deserialize(D: binary_editor) -> string?:
        let ver = D.read_string(4)
        guard ver == "toc0":
            return "toc: bad tag @ {D.offset}"
        var ti = D.read_byte()
        while ti != 0:
            let bi = D.read_int32()
            block_ixs[ti-1] = bi
            ti = D.read_byte()

        return nil

// A section of grid, starting at "top_left", of size "dims".
// All blocks referenced in the toc are expected to be of a uniform
// size, "pxsize".
class grid_chunk:
    toc: grid_toc
    data: string

    bounds = aabb2i{int2_0, int2_1*127}
    pxsize = int2_1 * 32

    // layer to render at
    layer = 0.0

    // Static meshes for the chunk
    meshes = [] :: resource<mesh>

    def serialize(D: binary_editor):
        // toc is a convenience reference, we intentionally do not serialize it.
        // That will be handled by the layers.
        D.write_string("chk0") // version 0
        serialize_bb2i(D, bounds)
        D.write_vertex2i(pxsize)
        D.write_float32(layer)
        D.write_rle_bytes(data)
        D.write_string("echk")

    def deserialize(D: binary_editor) -> string?:
        meshes = []
        let ver = D.read_string(4)
        guard ver == "chk0":
            return "chunk: bad tag @ {D.offset}"
        bounds = deserialize_bb2i(D)
        pxsize = D.read_vertex2i()
        layer = D.read_float32()
        data = D.read_rle_bytes(bounds.width() * bounds.height())
        if D.read_string(4) == "echk":
            return nil
        else:
            return "chunk: bad end tag @ {D.offset}"

    // If p is within the chunk, calls body with the index into data for the cell.
    private def with_index(p: int2, body):
        if bounds.contains(p):
            let rp = p - bounds.mins
            body(rp.x + rp.y*bounds.width)

    private def invalidate():
        if length(meshes) > 0:
            meshes = []

    // Returns the toc index at a given pos.  Returns 0 if the cell is not set.
    def toc_ix_at(p: int2) -> int:
        with_index(p) ix:
            return read_uint8_le(data, ix)
        return 0

    // Returns block index at given pos.  Returns -1 if the cell is not
    // set.
    def block_at(p: int2) -> int:
        let toc_ix = toc_ix_at(p)
        if toc_ix > 0:
            return toc.block_index(toc_ix)
        else:
            return -1

    // Returns block at internal relative coordinates, without bounds checking.
    private def block_at_intern(rp: int2) -> int:
        let ix = rp.x + rp.y*bounds.width
        let toc_ix = read_uint8_le(data, ix)
        if toc_ix > 0:
            return toc.block_index(toc_ix)
        else:
            return -1

    // Given a TOC index, sets it at the given position.  Do not confuse with 
    // the block index for images.  Does nothing if the point is out of range.
    def set_toc_index(p: int2, toc_ix: int):
        with_index(p) ix:
            data = write_int8_le(data, ix, toc_ix)
            invalidate()

    // Given a block index, adds the block to the TOC if it's not already there,
    // and sets the cell.
    def set_block(p: int2, blk_ix: int):
        let tocix = toc.assign_block(blk_ix)
        if tocix > 0:
            set_toc_index(p, tocix)

    def render():
        PERF.start("chunk render {bounds}")
        if length(meshes) == 0:
            PERF.start("gen chunk meshes")
            draw_begin()
            for(bounds.height) y:
                for(bounds.width) x:
                    let cc = int2{x, y}
                    let bix = block_at_intern(cc)
                    if bix >= 0:
                        draw_image(bix, bounds.mins*pxsize + cc*pxsize, layer)
            meshes = map(draw_finish_meshes()): 
                gl_set_mesh_texture(_.value, 0, 0, _.key)
                _.value
            PERF.stop()

        for(meshes) m:
            gl_render_mesh(m)
        PERF.stop()

// Creates a grid_chunk with the given size, using the given grid_toc.
def mk_grid_chunk(toc: grid_toc, top_left = int2_0, dims = int2_1*128, 
                  pxsize = int2_1 * 32, layer = 0.0) -> grid_chunk:
    assert dims.x > 0 and dims.y > 0
    assert pxsize.x > 0 and pxsize.y > 0
    assert abs(layer) <= draw_layer_range
    let data = ensure_size("", dims.x*dims.y, 0)
    return grid_chunk{toc: toc, data: data, bounds: aabb2i{top_left, top_left+dims-int2_1}, 
                      pxsize: pxsize, layer: layer}

// A layer made up of grid_chunks
class grid_layer:
    toc: grid_toc

    // Pixel size of cells
    pxsize = int2{32,32}

    // Size of chunks we will instantiate
    chunk_dims = int2{128, 128}

    // Layer the layer will be rendered on
    layer = 0.0

    // Calculated bounding box of contained chunks, in cell coordinates.
    cell_bb = aabb2i{int2_0, -int2_1}

    // Ordered chunk array
    chunks = [] :: grid_chunk

    def serialize(D: binary_editor):
        D.write_string("lay0") // version 0
        toc.serialize(D)
        D.write_vertex2i(pxsize)
        D.write_vertex2i(chunk_dims)
        D.write_float32(layer)
        serialize_bb2i(D, cell_bb)
        D.write_array(chunks) c:
            c.serialize(D)
        D.write_string("elay")

    def deserialize(D: binary_editor) -> string?: 
        def check(s):
            if s: return s
        let ver = D.read_string(4)
        guard ver == "lay0":
            return "layer: bad tag @ {D.offset}"
        check(toc.deserialize(D))
        pxsize = D.read_vertex2i()
        chunk_dims = D.read_vertex2i()
        layer = D.read_float32()
        cell_bb = deserialize_bb2i(D)
        chunks = D.read_array():
                    let c = grid_chunk{toc: toc, data: ""}
                    let err = c.deserialize(D)
                    if err:
                        return err
                    else:
                        c
        if D.read_string(4) == "elay":
            return nil
        else:
            return "layer: bad end tag @ {D.offset}"

    // Tries to find an existing chunk, and calls body(chunk) if it exists.
    def find_existing_chunk(cc: int2) -> grid_chunk?:
        guard cell_bb.contains(cc):
            return nil

        let ci = find(chunks) c: c.bounds.contains(cc)
        if ci >= 0:
            //TODO mru reorder?
            return chunks[ci]
        else:
            return nil

    // Looks up the chunk for the given cell coordinate, creating a new
    // one if necessary. 
    def chunk_for_cell(cc: int2) -> grid_chunk:
        let ce = find_existing_chunk(cc)
        if ce:
            return ce

        // quantitize chunk positions, never want overlapping chunks
        let tl = (cc / chunk_dims) * chunk_dims
        let c = mk_grid_chunk(toc, tl, chunk_dims, pxsize, layer)
        cell_bb = cell_bb.union(c.bounds) 
        push(chunks, c)
        return c

    // Render all of the chunks that overlap the given view bounds.
    def render(view: aabb2i):
        for(chunks) c:
            if view.overlaps(c.bounds):
                c.render()

    // TODO might need block operations here and in chunks to set multiple cells
    // at the same time.
    def toc_ix_at(cc: int2) -> int:
        let c = find_existing_chunk(cc)
        if c:
            return c.toc_ix_at(cc)
        else:
            return 0
    
    // For all of the cell coords in bb, calls body(tocix, pos)
    // Calls are in column major order
    def for_toc_ixs(bb: aabb2i, body):
        var ch = nil :: grid_chunk
        bb.for_allxy() cc:
            if not ch or not ch.bounds.contains(cc):
                ch = find_existing_chunk(cc)
            if ch:
                body(ch.toc_ix_at(cc), cc)
            else:
                body(0, cc)


    def block_at(cc: int2) -> int:
        let c = find_existing_chunk(cc)
        if c:
            return c.block_at(cc)
        else:
            return -1
       
    def set_block(cc: int2, blk_ix: int):
        guard cc.x >= 0 and cc.y >= 0
        let c = chunk_for_cell(cc)
        c.set_block(cc, blk_ix)

    def set_toc_index(cc: int2, toc_ix: int):
        guard cc.x >= 0 and cc.y >= 0
        let c = chunk_for_cell(cc)
        c.set_toc_index(cc, toc_ix)

    private def clip_cc_bb(bb: aabb2i):
        return aabb2i{max(int2_0, bb.mins), bb.maxs}

    def set_toc_index(cc_bb: aabb2i, toc_ix: int):
        // TODO: do we do this enough to split and batch this between chunks
        //       for efficiency?
        let bb = clip_cc_bb(cc_bb)
        bb.for_y() y:
            bb.for_x() x:
                set_toc_index(int2{x,y}, toc_ix)

// Contains wall and floor layers, and maintains the difference in cell sizes
// between the two. 
class grid_level:
    floor: grid_layer
    wall: grid_layer
    // Visibility map calculated from pov of player.  Viz calcs done in wall
    // coordinates, keep that in mind when dealing with floor coords.
    playerviz: propmap_bits
    playerseen: propmap_bits
    // Level lightmap
    lightmap: propmap_bytes

    // Lightmap for dynamic lights that is rebuilt on update calls.
    dynlightmap: propmap_bytes

    // Dynamic and static objects.
    objects = [] :: object_instance

    // Mask geometry built up to mark and light seen and areas that are not visible.
    mask_seen = nil :: resource<mesh>
    mask_viz  = nil :: resource<mesh>
    mask_light = nil :: resource<mesh>
    masks_invalidated = false

    // Set to true when objects have been added to or removed from the level.
    objects_dirty = false

    editing = false
    light_everything = false
    debug_lightmap = false

    def serialize(D: binary_editor):
        D.write_string("lev0")
        floor.serialize(D)
        wall.serialize(D)
        playerseen.serialize(D)
        lightmap.serialize(D)
        D.write_array(objects) o:
            o.serialize(D)
        D.write_string("elev")

    def deserialize(D: binary_editor) -> string?:
        def check(s):
            if s: return s
        let ver = D.read_string(4)
        guard ver == "lev0":
            return "level: bad tag @ {D.offset}"
        check(floor.deserialize(D))
        check(wall.deserialize(D))
        check(playerseen.deserialize(D))
        check(lightmap.deserialize(D))
        objects = D.read_array(): 
            let o = object_instance{-1, int2_0}
            check(o.deserialize(D))
            o
        if D.read_string(4) == "elev":
            objects_dirty = true
            return nil
        else:
            return "level: bad end tag @ {D.offset}"

    // Returns the cell coordinate bb for all of the wall cells at the given
    // floor cell coordinate.
    def wall_area(fc: int2) -> aabb2i:
        let tl = fc*layer_size_factor
        return aabb2i{tl, tl+int2_1*(layer_size_factor-1)}

    private def color_for_lmbyte(v: int) -> color:
        let c = clamp(float(v)/255.0, 0.0, 1.0)
        return color{c,c,c,1.0}

    private def get_lmlev(cc: int2) -> int:
        if light_everything: 
            return 255

        let lev = lightmap.get_byte(cc) + dynlightmap.get_byte(cc)
        return clamp(lev, 0, 255)

    def create_render_masks(view: aabb2i):
        let mb = mesh_builder{}
        let seen = mesh_builder{}
        let mb_light = mesh_builder{}

        // Build up mask in horizontal strips to cut down on the amount of geometry we need
        // to send over.
        let wallview = floor_bb_to_wall(view)
        wallview.for_y() y:
            var x = wallview.mins.x
            while x <= wallview.maxs.x:
                let wc = int2{x, y}
                if editing or playerviz.is_set(wc):
                    let ilev = get_lmlev(wc)
                    let runstart = x++
                    while x <= wallview.maxs.x and (editing or playerviz.is_set(int2{x,y})) and get_lmlev(int2{x,y}) == ilev:
                        x++
                    let tl = wall_to_px(int2{runstart, y})
                    let br = wall_to_px(int2{x, y+1})
                    let c = color_for_lmbyte(ilev)
                    mk_poly_indexed(mb_light, [
                                    PC{float3{tl.x, tl.y, seen_mask_layer}, c}, 
                                    PC{float3{br.x, tl.y, seen_mask_layer}, c}, 
                                    PC{float3{br.x, br.y, seen_mask_layer}, c}, 
                                    PC{float3{tl.x, br.y, seen_mask_layer}, c}])
                else:
                    if not editing and playerseen.is_set(wc):
                        // run of seen but not visible cells.
                        let runstart = x++
                        while x <= wallview.maxs.x and not playerviz.is_set(int2{x,y}) and playerseen.is_set(int2{x,y}):
                            x++
                        let tl = wall_to_px(int2{runstart, y})
                        let br = wall_to_px(int2{x, y+1})
                        let fwidth = float(x - runstart)
                        mk_poly_indexed(seen, [
                                        PT{float3{tl.x, tl.y, seen_mask_layer}, float2{0.0, 0.0}}, 
                                        PT{float3{br.x, tl.y, seen_mask_layer}, float2{fwidth, 0.0}}, 
                                        PT{float3{br.x, br.y, seen_mask_layer}, float2{fwidth, 1.0}}, 
                                        PT{float3{tl.x, br.y, seen_mask_layer}, float2{0.0, 1.0}}])

                    else:
                        // Run of not seen or visible cells
                        if not editing:
                            let runstart = x++
                            while x <= wallview.maxs.x and not playerviz.is_set(int2{x, y}) and not playerseen.is_set(int2{x,y}):
                                x++
                            let tl = wall_to_px(int2{runstart, y})
                            let br = wall_to_px(int2{x, y+1})
                            mk_poly_indexed(mb, [
                                            P{float3{tl.x, tl.y, seen_mask_layer}}, 
                                            P{float3{br.x, tl.y, seen_mask_layer}}, 
                                            P{float3{br.x, br.y, seen_mask_layer}}, 
                                            P{float3{tl.x, br.y, seen_mask_layer}}])
        if length(mb.pos3) > 0:
            mask_viz = mb.make_mesh_indexed("P")
            //print("notseen mesh size {mb.buffer_size()}")
        else:
            mask_viz = nil

        if length(seen.pos3) > 0:
            mask_seen = seen.make_mesh_indexed("PT")
            //print("seen mask mesh size {seen.buffer_size()}")
        else:
            mask_seen = nil

        if length(mb_light.pos3) > 0:
            mask_light = mb_light.make_mesh_indexed("PC")
            //print("light mask mesh size {mb_light.buffer_size()}")
        else:
            mask_light = nil

    // Masks out areas that are not visible by the player so they can't
    // be seen when we blast out the static meshes and applies light levels
    // to the already rendered bits.
    def mask_unseen_areas(view: aabb2i):
        if masks_invalidated:
            // All the work already done.
            create_render_masks(view)
            masks_invalidated = false

        if mask_viz:
            gl_set_shader("color")
            gl_blend(blend_none)
            gl_color(color{0.0, 0.0, 0.0, 0.0})
            gl_render_mesh(mask_viz)

        if mask_seen:
            gl_set_shader("textured")
            gl_color(color_white)
            gl_blend(blend_alpha)
            gl_set_primitive_texture(0, get_stipple_texture())
            gl_render_mesh(mask_seen)

        if mask_light:
            gl_set_shader("color_attr")
            gl_blend(if debug_lightmap: blend_none else: blend_multiply)
            gl_color(color_white)
            gl_render_mesh(mask_light)

    // before change fullscreen
    // notseen mesh size 2236608
    // seen mask mesh size 68120

    // Cleans up the seen record - we don't want to save data for seen
    // tiles in clean map.
    def clear_seen():
        playerseen.clear(false)
                 
    // Provided for editor, make it so there is no fog of war.
    def i_see_all():
        playerviz.clear(true)
        mask_viz = nil
        mask_seen = nil
        mask_light = nil

    // Adds an object to the level.  Assumes the object is on the floor
    // at it's current cell position.
    def add_object(o: object_instance):
        set_push(objects, o)
        objects_dirty = true
            
    // This might change the render state and shader.
    def render(view: aabb2i):
        PERF.start("level render")
        gl_color(color_white)
        PERF.time("floor render"):
            gl_blend(blend_none)
            gl_set_shader("textured_color")
            floor.render(view)
        PERF.time("wall render"):
            wall.render(aabb2i{view.mins*layer_size_factor, view.maxs*layer_size_factor})

        // Very cheesy shadow effect for walls.
        // TODO: fix up and parameterize color at least?
        // TODO: would also look better if we generate a separate shadow mesh, 
        //       so it isn't obviously wrong at corners.
        // TODO: won't this look odd at chunk boundaries if the chunks are drawn
        //       in the wrong order?
        PERF.start("shadow render")
        gl_set_shader("color")
        gl_blend(blend_multiply)
        gl_color(color{0.5, 0.5, 0.5, 0.5}):
            gl_translate(float3{8.0,8.0,-0.5}):
                wall.render(aabb2i{view.mins*layer_size_factor, view.maxs*layer_size_factor})
        PERF.stop()

        PERF.start("render dynamics")
        gl_blend(blend_alpha)
        gl_set_shader("textured_color_acut")
        //TODO don't draw dynamic if floor tile is entirely out of player viz
        draw_begin()
        for(objects) o:
            if o.is_on_floor() and o.viz_overlaps(view):
                o.draw()
        draw_finish()
        PERF.stop()

        PERF.time("mask unseen"):
            gl_blend(blend_none)
            gl_set_shader("textured_color")
            mask_unseen_areas(view)
        PERF.stop()
    
    private def ensure_objects_indexed():
        if length(objects) > 1:
            qsort_in_place(objects) a, b: 
                a.cc.x < b.cc.x or (a.cc.x == b.cc.x and a.cc.y < b.cc.y)
            print("ARF {map(objects): _.cc}")
        objects_dirty = false

    // Finds the where the given point would be in the objects array.
    private def obj_index_cc(cc: int2) -> int:
        ensure_objects_indexed()
        let _found, i = binary_search_by_key(objects, cc) o, k:
            o.cc.x < k.x or (o.cc.x == k.x and o.cc.y < k.y)
        return i

    // Calls body(obj) for each object at the given position in the level.
    def for_objects_at(cc: int2, body):
        var i = obj_index_cc(cc)
        while i < length(objects) and objects[i].cc == cc:
            body(objects[i])
            i++

    // Calls body(obj) for all objects within the given cell coordinate 
    // bounding box.
    def for_objects_in(bb: aabb2i, body):
        var i = obj_index_cc(bb.mins)

        while i < length(objects) and objects[i].cc.x <= bb.maxs.x:
            if bb.contains(objects[i].cc):
                body(objects[i])
            i++

    private def wc_blocks_light(wc: int2) -> bool:
        //TODO repeated object lookups so slow
        if wall.toc_ix_at(wc) != 0:   //TODO not checking opaque flag
            return true
        let cc = wall_to_floor(wc)
        let fi = find(objects): _.cc == cc and _.blocks_light(wc)
        return fi >= 0

    // Updates viz and light state for the level.  maxview_r should be in wall
    // coordinates.
    def update(d_t: float, turn_taken: bool, player_pos: int2, maxview_r: int, view: aabb2i):
        if turn_taken:
            masks_invalidated = true
            playerviz.clear(false)
            let w_player = floor_to_wall(player_pos) + layer_size_factor/2-1
            let tl = w_player - int2_1*maxview_r
            let bb = aabb2i{tl, tl + int2_1*maxview_r*2}
            walk_visible_tiles_quad(w_player, bb, fn(p): wc_blocks_light(p)) cc:
                playerviz.set(cc)
                playerseen.set(cc)
            playerviz.set(w_player)
            playerseen.set(w_player)

            let view_w = floor_bb_to_wall(view)
            dynlightmap.clear(0)
            for(objects) o:
                let l = o.get_lightinfo()
                guard l
                let l_wc = floor_to_wall(o.cc) + layer_size_factor/2-1
                let lbb = l.world_aabb(l_wc)
                guard lbb.overlaps(view_w)
                walk_visible_tiles(l_wc, lbb, fn(p): wc_blocks_light(p)) wc:
                    var lc = l.light_contribution(l_wc, wc)
                    let dp = wc - l_wc
                    if abs(dp.x) == abs(dp.y) or wc.x == l_wc.x or wc.y == l_wc.y:
                        // shadowcasting octants overlap, so we do this to 
                        // avoid double application along octant borders
                        lc /= 2
                    dynlightmap.adj_byte(wc, lc)
                dynlightmap.adj_byte(l_wc, l.l0)

        if objects_dirty:
            // Sort the objects by ascending x, y to accelrate lookups by area.
            ensure_objects_indexed()

def mk_grid_level(act_floor_pxsize: int2) -> grid_level:
    let chdim = int2{128,128}
    return grid_level{
        floor: grid_layer{toc: grid_toc{}, pxsize: act_floor_pxsize, layer: floor_render_layer, chunk_dims: chdim},
        wall: grid_layer{toc: grid_toc{}, pxsize: act_floor_pxsize/layer_size_factor, layer: wall_render_layer, chunk_dims: chdim},
        playerviz: propmap_bits(viz_chunk_dims, false), 
        playerseen: propmap_bits(viz_chunk_dims, false),
        lightmap: propmap_bytes(viz_chunk_dims, 120), 
        dynlightmap: propmap_bytes(viz_chunk_dims, 0)}
        
def save_grid_level(l: grid_level, file: string) -> string?:
    let D = binary_editor{}
    l.serialize(D)
    if write_file(file, substring(D.data, 0, D.offset)):
        return nil
    else:
        return "save_grid_level: could not write file {file}"

def load_grid_level(fname: string) -> string?, grid_level:
    let rv = grid_level{grid_layer{grid_toc{}}, grid_layer{grid_toc{}}, 
                        propmap_bits(viz_chunk_dims, false),
                        propmap_bits(viz_chunk_dims, false),
                        propmap_bytes(viz_chunk_dims, 120), 
                        propmap_bytes(viz_chunk_dims, 0)}
    let dat = read_file(fname)
    guard dat:
        return "load_grid_level: could not read {fname}", rv
    let D = binary_editor{data: dat, offset: 0}
    let err = rv.deserialize(D)
    return err, rv
