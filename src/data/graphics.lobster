// A graphic.  Currently, it can be a full texture, or a region on a texture.
import core.algs
import core.logging
import core.rects

import data.meshbuilder
import data.textures

// A texture and the associated texture rectangles defining the sub-images.
struct graphics_group:
   tx: tx_handle
   regions: [rectf]

private let graphics_groups = [] :: graphics_group

// Handle for a graphic.
struct graphic_handle:
   grp_ix: int
   reg_ix: int

   def texture() -> tx_handle:
      return graphics_groups[grp_ix].tx

   def region() -> rectf:
      return graphics_groups[grp_ix].regions[reg_ix]

   def set_region(reg: rectf):
      graphics_groups[grp_ix].regions[reg_ix] = reg
      return this

let INVALID_GRAPHIC_HANDLE = graphic_handle{-1, -1}

// Given a texture, and a pixel size for the size of subregions, 
// generates graphics for each of the regions, in row major order. 
// Returns the array of handles.
def define_graphics(texture: tx_handle, subreg_size: int2, border: int2 = int2{0,0}) -> [graphic_handle]:
   debug(): "define_graphics {texture.path}, subreg_size {subreg_size}"
   let tsz = texture.dimensions()
   let outer_sz = subreg_size + border
   if (tsz.x % outer_sz.x) != 0 or (tsz.y % outer_sz.y) != 0:
      error(): "define_graphic: texture size {tsz} not evenly divisible by total subregion size {outer_sz}"

   let outer_tc_dims =  outer_sz.to_f / tsz.to_f
   let inner_tc_dims = subreg_size.to_f / tsz.to_f
   let border_step = border.to_f / tsz.to_f
   let n_across = tsz.x / outer_sz.x
   let n_down = tsz.y / outer_sz.y
   let rv = [] :: graphic_handle
   let rects = []
   let grp_ix = length(graphics_groups)
   
   for(n_down) y:
      for(n_across) x:
         let tc = float2{outer_tc_dims.x * float(x), outer_tc_dims.y * float(y)} + border_step
         push(rv, graphic_handle{grp_ix, length(rv)})
         push(rects, rectf{tc, inner_tc_dims})

   push(graphics_groups, graphics_group{texture, rects})
   return rv

// Struct that has all the information needed to locate the correct graphics handle. 
struct graphic_path:
   // Path for the image.
   image: string  
   // Dims of sub-images in pixels
   sub_image_dims: int2
   // index of the sub-image.
   ix: int
   // Border around the subimage.
   border: int2 = int2{0, 0}

// Returns the graphics handle for a graphics_path struct.
// Loads the texture if it has not been loaded before.  Returns 
// INVALID_GRAPHIC_HANDLE if the image can't be resolved.
def graphic_by_name(gname: graphic_path) -> graphic_handle:
   let gix = find(graphics_groups) gg: gg.tx.path == gname.image

   if gix >= 0:
      return graphic_handle{gix, gname.ix}
   else:
      let base_tx = load_tx(gname.image)
      
      if base_tx == INVALID_TX_HANDLE:
         return INVALID_GRAPHIC_HANDLE
      else:
         let handles = define_graphics(base_tx, gname.sub_image_dims, gname.border)
         return handles[gname.ix]
