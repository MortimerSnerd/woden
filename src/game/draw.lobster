// Presents a simple interface to drawing images. Internally builds up 
// meshes and texture atlases from the calls to draw so it won't be slow.
//  
// let handle = block_index_for("rcorner.png")
// draw_ortho()
// draw_begin()
// draw_image(handle, 100, 100)
// draw_image(handle, 150, 100)
// draw_finish()
// 
// Should also be able to get an array of texture/mesh pairs at the conclusion of
// draw finish, so static areas can be drawn without a lot of traffic to the GPU.
import color

import core.algs
import data.meshbuilder

import game.blocks

// How far the layer can be from 0 before it will no longer render.
let draw_layer_range = 10.0

// Stack of state we use between begin and finish calls to accumulate
// geometry to be drawn.
private var MBL = [] :: mesh_builder_lookup

// Flags that control drawing
enum_flags draw_flags:
    df_hflip            // Flip image horizontally.
    df_vflip

// Should call this before a batch of draw calls.
def draw_begin():
    push(MBL, mesh_builder_lookup{})

private def get_texcoords(handle, flags):
    if flags == 0:
        return blk_texcoords[handle]

    let tc = blk_texcoords[handle]
    var tlx = tc[0]
    var tly = tc[1]
    var brx = tc[2]
    var bry = tc[3]

    if flags.has(df_hflip):
        let tx = brx
        brx = tlx
        tlx = tx

    if flags.has(df_vflip):
        let ty = bry
        bry = tly
        tly = ty

    return float4{tlx,tly,brx,bry}
    

// Batches a draw of an unscaled unrotated image.  Must be bracketed by
// calls to draw_begin() and draw_finish()/draw_finish_meshes().
// Assumes pixel coordinate system.  pos should be the top left of 
// the image.  abs(layer) should be <= draw_layer_range.  Larger layers
// are closer to the camera.
def draw_image(handle: int, pos: int2, layer=0.0, flags = 0, tint=color_white):
    let mb = MBL[length(MBL)-1].lookup(BLOCK_PAGES[blk_page_no[handle]])
    let psz = float(blk_img_size[handle])
    let tc = get_texcoords(handle, flags)
    let fpos = float3{float(pos.x), float(pos.y), layer}
    mk_poly_indexed(mb, [
        PTC{fpos + float3{0.0, 0.0, 0.0},     float2{tc[0], tc[1]}, tint},
        PTC{fpos + float3{psz.x, 0.0, 0.0},   float2{tc[2], tc[1]}, tint},
        PTC{fpos + float3{psz.x, psz.y, 0.0}, float2{tc[2], tc[3]}, tint},
        PTC{fpos + float3{0.0, psz.y, 0.0},   float2{tc[0], tc[3]}, tint}])
    

// Finishes a batch of draw calls, but does not render them.  Returns
// the texture mesh pairs that will render them.  You have to call 
// this or draw_finish() for each draw_begin(), but not both.
def draw_finish_meshes() -> [kvpair<resource<texture>, resource<mesh> >]:
    let mbl = pop(MBL)
    return mbl.build_meshes_indexed("PTC")
    
// Call this when finished drawing.  The results will be rendered immediately.
// Uses whatever shader is active.  Does not change shader, blending or any 
// other render state, so callers need to batch things correctly for transparencies, 
// etc...
def draw_finish():
    let meshes = draw_finish_meshes()
    for(meshes) p:
        gl_set_primitive_texture(0, p.key)
        gl_render_mesh(p.value)

// Sets the model view up for an ortho view that sets up pixel coordinates for the
// view.  Put in it's own function because initially the setup was wrong, and tricky
// to get +y down.
def draw_ortho(logical_size: int2):
    let sz = float(logical_size)

    gl_ortho3d(float3{sz.x*0.5, sz.y*0.5, 0.0}, 
               float3{sz.x*0.5, sz.y*0.5, draw_layer_range})

