// Lookup so we don't reload textures all of the time.
// We don't use the equivalent functionalty in the lobster
// texture module, because it will end the program on a failed
// texture load.
//
// Texture names can also have decorations appended to the end
// to specify texture flags.  Options are preceded by the '|' character.
//
// Recognized options:
//      N - nearest neighbor interpolation
//      M - no mipmaps
//      C - clamp.
//
// Ex:
//        "dist/images/sprites.png|NM"
//
import texture

import core.logging

private let tx_path = [] :: string
private let tx_res = [] :: resource<texture>

// Splits a path into a "path", texture_options pair.
private def parse_path(path: string) -> string, int:
   var i = find(path) c: c == '|'

   if i < 0:
      return path, 0
   else:
      let p = substring(path, 0, i)
      var opts = 0
      i += 1
      while i < length(path):
         switch path[i]:
            case 'N':
               opts |= texture_format_nearest_mag | texture_format_nearest_min
            case 'M':
               opts |= texture_format_nomipmap
            case 'C':
               opts |= texture_format_clamp
            default:
               error(): "unknown texture option {path[i]} in {path}"
         i += 1

      return p, opts

struct tx_handle:
   h: int

   def path() -> string:
      return tx_path[h]

   //TODO should this invalidate tx_res?
   def set_path(p: string) -> tx_handle:
      tx_path[h] = p
      return this

   def texture() -> resource<texture>:
      return tx_res[h]

   def set_texture(r: resource<texture>) -> tx_handle:
      tx_res[h] = r
      return this

   def is_valid() -> bool:
      return h >= 0

   def operator<(other) -> bool:
      return h < other.h

   def dimensions() -> int2:
      return gl_texture_size(tx_res[h])

let INVALID_TX_HANDLE = tx_handle{-1}
let INVALID_TX_IMAGE = "dist/images/Bubba.png"
var INVALID_TX = nil :: resource<texture>

// Call once on startup to initialize, after gl_window() has been called.
def init_textures():
   INVALID_TX = gl_load_texture(INVALID_TX_IMAGE)

// Loads a texture if necessary, returning an index into tx_res.
def load_tx(path: string) -> tx_handle:
   debug(): "load_tx {path}"
   var i = find(tx_path): _ == path

   if i < 0:
      let true_path, txopts = parse_path(path)
      i = length(tx_path)
      var tx = gl_load_texture(true_path, txopts)  //TODO any texture flags specific to load time?
      if tx == nil:
         tx = INVALID_TX
         error(): "Could not load texture {path}"

      if tx:
         push(tx_path, path)
         push(tx_res, tx)
      else:
         fatal("Impossible: no texture placeholder")

   return tx_handle{i}
