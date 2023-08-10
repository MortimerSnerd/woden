// For now, just simple support for writing uncompressed truecolor targa files.  
import data.binary

let TARGA_HEADER_SIZE = 18

let TARGA_TYPE_UNCOMPRESSED_TRUECOLOR = 2
private let NO_COLORMAP = 0

struct targa_opts:
   width  = 128
   height = 128
   bpp    = 24
   type   = TARGA_TYPE_UNCOMPRESSED_TRUECOLOR

   bottom_to_top = false

   def validates() -> bool:
      return width >= 0 and height >= 0 and (bpp == 24 or bpp == 32)

   def alpha_depth() -> int:
      if bpp == 24:
         return 0
      else:
         return 8

def write_targa_header(be: binary_editor, opts: targa_opts):
   assert opts.validates()
   var imgdesc = (opts.alpha_depth() & 0xF)

   if opts.bottom_to_top:
      imgdesc |= 1 << 5

   be.write_byte(0)           // id length
   be.write_byte(NO_COLORMAP)
   be.write_byte(opts.type)
   for(5): be.write_byte(0)      // colormap info
   be.write_int16(0)             // xorigin
   be.write_int16(0)             // yorigin
   be.write_int16(opts.width)
   be.write_int16(opts.height)
   be.write_byte(opts.bpp)
   be.write_byte(imgdesc)

// Given a string from gl_read_texture(), writes it out in the format expected 
// for a 24 or 32bpp targa file.
def write_pixels_from_texture(be: binary_editor, tx_pixels: string, 
                              include_alpha = false):
   let rd = binary_editor{data: tx_pixels}
   while(rd.offset < length(tx_pixels)):
      let r = rd.read_byte()
      let g = rd.read_byte()
      let b = rd.read_byte()
      let a = rd.read_byte()

      be.write_byte(b)
      be.write_byte(g)
      be.write_byte(r)
      if include_alpha:
         be.write_byte(a)

