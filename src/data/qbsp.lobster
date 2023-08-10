// Test module to see if we can load quake 2 BSP files in lobster without
// any native extensions.
//
// Largely taken from files.h and gl3_model.c from the Yamagi Quake 2 client.
import color
import std

import core.bitset
import core.lexbase
import data.binary

enum lump_names:
   lump_entities, lump_planes, lump_vertexes, lump_visibility,
   lump_nodes, lump_texinfo, lump_faces, lump_lighting, lump_leaves, lump_leaffaces,
   lump_leafbrushes, lump_edges, lump_surfedges, lump_models, lump_brushes, lump_brush_sides,
   lump_pop, lump_areas, lump_areaportals, num_of_lumps

let lump_to_name = map(num_of_lumps) l: "{lump_names(l)}"

enum plane_types:
   plane_x, plane_y, plane_z, plane_any_x, plane_any_y, plane_any_z,
   num_of_plane_types
let plane_type_to_name = map(num_of_plane_types) l: "{plane_types(l)}"

// Original version.  Only one supported for now.
let BSPVERSION = 38
private let MIPLEVELS = 4
let MAX_LIGHT_MAPS = 4

// The header of wal files
struct bsp_miptex:
   name:     string
   width:    int
   height:   int
   offsets:  int4
   animname: string
   flags:    int
   contents: int
   value:    int

// Loaded image data.
class bsp_image: 
   dims: int2
   data: string

struct bsp_face:
   plane_num:  int
   side:       int
   first_edge: int
   num_edges:  int
   texinfo:    int
   styles:     string // length == MAX_LIGHT_MAPS. Starting from beginning, 0 means a lightmap is present.
   lightofs:   int    // Offset of lightmaps from start of lump_lighting(?)

   def desc() -> string:
      return "plane={plane_num} side={side} fst_edge={first_edge} n={num_edges} texinfo={texinfo} styles={concat_string(map(styles) s: "{s}", ",")} lm_offset={lightofs}"


// non-leaf node for bsp tree.  Surfaces here used for collision detection, not
// rendering.
struct bsp_node:
   plane_num: int
   children: int2     // <0 means leaf at -(leafs+1)
   mins: float3        // BB for frustum culling? 
   maxs: float3
   first_face: int
   num_faces: int

   def desc() -> string:
      return "plane={plane_num}, children=[{children.x} {children.y}], mins={mins}, maxs={maxs}, first_face={first_face}, num_faces={num_faces}"


struct bsp_leaf:
   contents: int
   cluster: int
   area: int
   mins: float3
   maxs: float3
   first_face: int
   num_faces: int
   first_brush: int
   num_brushes: int

   def desc() -> string:
      return "contents=0x{number_to_string(contents, 16, 1)}, cluster={cluster}, area={area}, mins={mins}, maxs={maxs}, first_face={first_face}, num_faces={num_faces}, first_brush={first_brush}, num_brushes={num_brushes}"

struct bsp_lump:
   fileofs: int
   filelen: int

   // Return seekpos of next lump after this one.
   def next() -> int:
      return fileofs + filelen

struct bsp_plane:
   normal: float3
   dist:   float
   type:   int     // note, this seems to be a classification for axis planes, used to simplify some calc.

   def desc() -> string:
      return "({normal.x}, {normal.y}, {normal.z}) dist={dist}\t{plane_type_to_name[type]}"

struct bsp_texinfo:
   vecs:         [float4]    // s and t entries for vectors used for calculating texture coordinates.
   flags:        int
   value:        int
   texture:      string
   next_texinfo: int

   def desc() -> string:
      return "{texture}\t{concat_string(map(vecs) v: "({v.x},{v.y},{v.z},{v.w})", ", ")}\tflags={flags}\tvalue={value}\tnext={next_texinfo}"

struct bsp_viz_offset:
   pvs: int
   phs: int

   def desc() -> string:
      return "pvs={pvs}, phs={phs}"

struct bsp_brush_side:
   plane_num: int
   texinfo: int

   def desc() -> string:
      return "plane={plane_num}, texinfo={texinfo}"

struct bsp_brush:
   first_side: int
   num_sides: int
   contents: int

   def desc() -> string:
      return "first_side={first_side}, num_sides={num_sides}, contents=0x{number_to_string(contents, 16, 1)}"

struct bsp_model:
   mins: float3
   maxs: float3
   origin: float3
   head_node: int
   first_face: int
   num_faces: int

   def desc() -> string:
      return "mins={mins}, maxs={maxs}, origin={origin}, head_node={head_node}, first_face={first_face}, num_faces={num_faces}"

// Flags for bsp_texinfo
let SURF_LIGHT   = 0x1    // value is strength
let SURF_SLICK   = 0x2
let SURF_SKY     = 0x4
let SURF_WARP    = 0x8
let SURF_TRANS33 = 0x10   // 33% transparent
let SURF_TRANS66 = 0x20   // 66%     ..  
let SURF_FLOWING = 0x40
let SURF_NODRAW  = 0x80

// Contents flags
let CONTENTS_SOLID        = 0x00000001
let CONTENTS_WINDOW       = 0x00000002
let CONTENTS_AUX          = 0x00000004
let CONTENTS_LAVA         = 0x00000008
let CONTENTS_SLIME        = 0x00000010
let CONTENTS_WATER        = 0x00000020
let CONTENTS_MIST         = 0x00000040
let CONTENTS_AREAPORTAL   = 0x00008000
let CONTENTS_PLAYERCLIP   = 0x00010000
let CONTENTS_MONSTERCLIP  = 0x00020000
let CONTENTS_CURRENT_0    = 0x00040000
let CONTENTS_CURRENT_90   = 0x00080000
let CONTENTS_CURRENT_180  = 0x00100000
let CONTENTS_CURRENT_270  = 0x00200000
let CONTENTS_CURRENT_UP   = 0x00400000
let CONTENTS_CURRENT_DOWN = 0x00800000
let CONTENTS_DEADMONSTER  = 0x04000000
let CONTENTS_DETAIL       = 0x08000000
let CONTENTS_TRANSLUCENT  = 0x10000000
let CONTENTS_LADDER       = 0x20000000
let LAST_VISIBLE_CONTENTS = CONTENTS_MIST


// #bytes of BSP structures in serialized form.
private let WORDSZ                 = 4
private let SHORTSZ                = 2
private let sizeof_bsp_plane       = 3*WORDSZ   + WORDSZ  + WORDSZ
private let sizeof_bsp_edge        = 2*SHORTSZ
private let sizeof_bsp_face        = SHORTSZ + SHORTSZ + WORDSZ + SHORTSZ + SHORTSZ + WORDSZ + WORDSZ
private let bsp_texinfo_name_sz    = 32
private let sizeof_bsp_texinfo     = 2*4*WORDSZ + WORDSZ + WORDSZ + bsp_texinfo_name_sz + WORDSZ
private let sizeof_bsp_node        = 4 + 4*2 + 2*3 + 2*3 + 2 + 2
private let sizeof_bsp_leaf        = 4 + 2 + 2 + 2*3 + 2*3 + 2 + 2 + 2 + 2
private let sizeof_bsp_brush_side  = 2 + 2
private let sizeof_bsp_brush       = 4 + 4 + 4
private let sizeof_bsp_model       = 4*3 + 4*3 + 4*3 + 4 + 4 + 4

// bsp_texinfo flags
let TEXINFO_SPECIAL  = 1
let TEXINFO_MISSING  = 2

// Reader and container for a BSP file.  Mainly to have the byte string offset a member that can 
// be modfied, without a lot of awkward naming you get from multiple returns
// for n different versions of the offset.
class bsp_file:
   D            = binary_editor{}
   version      = 0
   lump_toc     = [] :: bsp_lump         // Lump table of contents.   One entry for each lump_name
   planes       = [] :: bsp_plane
   vertexes     = [] :: float3
   faces        = [] :: bsp_face
   edges        = [] :: int2
   textures     = [] :: bsp_texinfo
   surf_edges   = [] :: int              // Indices into edges, ordered so surface edges are contiguous. 
   nodes        = [] :: bsp_node
   leaf_faces   = [] :: int              // Sequences of faces for bsp nodes and leaves
   leaves       = [] :: bsp_leaf
   viz_index    = [] :: bsp_viz_offset
   brush_sides  = [] :: bsp_brush_side
   brushes      = [] :: bsp_brush
   models       = [] :: bsp_model
   leaf_brushes = [] :: int

   num_clusters = 0

   // Returns an empty string on success, or an error message on failure.
   def parse(bytes: string) -> string?:
      D.data = bytes
      D.offset = 0
      
      D.read_int32() // ident
      version = D.read_int32()
      if version != BSPVERSION:
         return "Unsupported bsp version: {version}"

      lump_toc = []
      for(num_of_lumps):
         push(lump_toc, read_lump())

      load_planes(lump_toc[lump_planes])
      load_vertexes(lump_toc[lump_vertexes])
      load_texinfo(lump_toc[lump_texinfo])
      load_faces(lump_toc[lump_faces])
      load_edges(lump_toc[lump_edges])
      load_surfedges(lump_toc[lump_surfedges])
      load_leaf_faces(lump_toc[lump_leaffaces])
      load_nodes(lump_toc[lump_nodes])
      load_leaves(lump_toc[lump_leaves])
      load_viz_index(lump_toc[lump_visibility])
      load_brush_sides(lump_toc[lump_brush_sides])
      load_brushes(lump_toc[lump_brushes])
      load_models(lump_toc[lump_models])
      load_leaf_brushes(lump_toc[lump_leafbrushes])

      return nil

   def get_entities_string() -> string:
      return substring(D.data, lump_toc[lump_entities].fileofs, lump_toc[lump_entities].filelen)

   // Walks the tree for a aabb defined by mins, maxs, calling body on 
   // the raw node/leaf number for each node/leaf visited.
   def for_nodes_intersecting_aabb(mins: float3, maxs: float3, start_node: int, body):
      let todo = [start_node]

      while length(todo) > 0:
         let node = pop(todo)

         if node < 0:
            body(node)  // Just report the leaf.
         else:
            if aabb_overlaps(nodes[node].mins, nodes[node].maxs, mins, maxs):
               body(node)
               let norm = planes[nodes[node].plane_num].normal
               let d    = planes[nodes[node].plane_num].dist
               let prod_min = dot(mins, norm) - d
               let prod_max = dot(maxs, norm) - d

               if prod_min > 0.0 or prod_max > 0.0:
                  push(todo, nodes[node].children[0])

               if prod_min <= 0.0 or prod_max <= 0.0:
                  push(todo, nodes[node].children[1])


   def for_nodes_intersecting_aabb(mins: int3, maxs: int3, start_node: int, body):
      for_nodes_intersecting_aabb(float(mins), float(maxs), start_node, body)

   // Decompresses the visibility set for the given cluster to a bitset.
   def visibility_set_for_cluster(c: int) -> bitset:
      //NB this works because core.bitset is addressed the same way
      // the uncompressed PVS is.
      let rv = mk_bitset(num_clusters+1)
      if c >= 0:
         D.offset = lump_toc[lump_visibility].fileofs + viz_index[c].pvs
         var oi = 0

         while oi < length(rv.bytes):
            let b = D.read_byte()

            if b != 0:
               write_int8_le(rv.bytes, oi, b)
               oi++
            else:
               let count = D.read_byte()
               oi += count

      return rv

   // Extracts pixels for the given face's lightmap.
   def lightmap_for_face(face_ix: int, lm_dims: int2, style = 0) -> [color]:
      let rv = []
      D.offset = lump_toc[lump_lighting].fileofs + faces[face_ix].lightofs + lm_dims.x*lm_dims.y*3*style
      for(lm_dims.x*lm_dims.y):
         let r = D.read_byte()
         let g = D.read_byte()
         let b = D.read_byte()

         push(rv, color{float(r)/255.0, float(g)/255.0, float(b)/255.0, 1.0})

      return rv

   // Returns the color for the lightmap at the given texture coordinates.
   def lightmap_color_lookup(face_ix: int, lm_dims: int2, style: int, tc: int2) -> color:
      let base = lump_toc[lump_lighting].fileofs + faces[face_ix].lightofs + lm_dims.x*lm_dims.y*3*style
      let atc = tc % lm_dims
      D.offset = base + atc.x*3 + atc.y*lm_dims.x*3
      let r = D.read_byte()
      let g = D.read_byte()
      let b = D.read_byte()
      return color{float(r)/255.0, float(g)/255.0, float(b)/255.0, 1.0}

   private def load_leaf_faces(lump):
      leaf_faces = []
      D.offset = lump.fileofs
      assert((lump.filelen % 2) == 0)
      let nfaces = lump.filelen / 2
      for(nfaces):
         push(leaf_faces, D.read_short())

   private def load_leaf_brushes(lump):
      leaf_brushes = []
      D.offset = lump.fileofs
      assert((lump.filelen % 2) == 0)
      let num_brushes = lump.filelen / 2
      for(num_brushes):
         push(leaf_brushes, D.read_ushort())
      
   private def load_models(lump):
      models = []
      D.offset = lump.fileofs
      assert((lump.filelen % sizeof_bsp_model) == 0)
      let num_brushes = lump.filelen / sizeof_bsp_model
      for(num_brushes):
         push(models, read_model())

   private def read_model():
      let mins = D.read_vertex3f()
      let maxs = D.read_vertex3f()
      let origin = D.read_vertex3f()
      let hnode = D.read_int32()
      let ff = D.read_int32()
      let nf = D.read_int32()

      return bsp_model{mins, maxs, origin, hnode, ff, nf}

   private def load_brushes(lump):
      brushes = []
      D.offset = lump.fileofs
      assert((lump.filelen % sizeof_bsp_brush) == 0)
      let num_brushes = lump.filelen / sizeof_bsp_brush
      for(num_brushes):
         push(brushes, read_brush())

   private def read_brush():
      let fst = D.read_int32()
      let num = D.read_int32()
      let contents = D.read_int32()
      return bsp_brush{fst, num, contents}

   private def load_brush_sides(lump):
      brush_sides = []
      D.offset = lump.fileofs
      assert((lump.filelen % sizeof_bsp_brush_side) == 0)
      let num_sides = lump.filelen / sizeof_bsp_brush_side
      for(num_sides):
         push(brush_sides, read_brush_side())

   private def read_brush_side():
      let plane = D.read_ushort()
      let texinfo = D.read_short()
      return bsp_brush_side{plane, texinfo}

   private def load_viz_index(lump):
      viz_index = []
      D.offset = lump.fileofs
      num_clusters = D.read_uint32()

      for(num_clusters):
         let pvs = D.read_uint32()
         let phs = D.read_uint32()
         push(viz_index, bsp_viz_offset{pvs, phs})

   def num_clusters() -> int:
      return length(viz_index)

   private def load_leaves(lump):
      leaves = []
      D.offset = lump.fileofs
      assert((lump.filelen % sizeof_bsp_leaf) == 0)
      let n_leaves = lump.filelen / sizeof_bsp_leaf
      for(n_leaves):
         push(leaves, read_leaf(lump))

   private def read_leaf(lump):
      if (D.offset + sizeof_bsp_leaf) > lump.next:
         return "EOF reading leaf @ {D.offset}" from parse
      let con = D.read_int32()
      let clus = D.read_short()
      let area = D.read_short()
      let mins = D.read_vertex3short()
      let maxs = D.read_vertex3short()
      let ff = D.read_short()
      let nf = D.read_short()
      let fb = D.read_short()
      let nb = D.read_short()

      return bsp_leaf{con, clus, area, float(mins), float(maxs), ff, nf, fb, nb}

   private def load_nodes(lump):
      nodes = []
      D.offset = lump.fileofs
      assert((lump.filelen % sizeof_bsp_node) == 0)
      let n_nodes = lump.filelen / sizeof_bsp_node
      for(n_nodes):
         push(nodes, read_node(lump))

   private def read_node(lump) -> bsp_node:
      if (D.offset + sizeof_bsp_node) > lump.next:
         return "EOF reading node @ {D.offset}" from parse
      let pn = D.read_int32()
      let children = D.read_vertex2i()
      let mn = D.read_vertex3short()
      let mx = D.read_vertex3short()
      let ff = D.read_short()
      let nf = D.read_short()
      return bsp_node{pn, children, float(mn), float(mx), ff, nf}

   private def load_surfedges(lump):
      surf_edges = []
      D.offset = lump.fileofs
      assert((lump.filelen % WORDSZ) == 0)
      let n_edges = lump.filelen / WORDSZ
      for(n_edges):
         push(surf_edges, D.read_int32())

   private def load_texinfo(lump):
      textures = []
      D.offset = lump.fileofs
      assert((lump.filelen % sizeof_bsp_texinfo) == 0)
      let n_ents = lump.filelen / sizeof_bsp_texinfo
      for(n_ents):
         if (D.offset + sizeof_bsp_texinfo) > lump.next:
            return "load_texinfo: EOF reading lump @ {D.offset}" from parse
         let vs = []
         for(2):
            push(vs, D.read_vertex4f())
         let flags = D.read_int32()
         let value = D.read_int32()
         let name = D.read_string(bsp_texinfo_name_sz)
         let next = D.read_int32()
         push(textures, bsp_texinfo{vs, flags, value, name, next})

   private def load_edges(lump):
      edges = []
      D.offset = lump.fileofs
      assert((lump.filelen % sizeof_bsp_edge) == 0)
      let n_edges = lump.filelen / sizeof_bsp_edge
      for(n_edges):
         push(edges, D.read_vertex2short())

   private def load_faces(lump):
      faces = []
      D.offset = lump.fileofs
      assert((lump.filelen % sizeof_bsp_face) == 0)
      let n_faces = lump.filelen / sizeof_bsp_face
      for(n_faces):
         push(faces, read_face(lump))

   private def load_planes(lump):
      D.offset = lump.fileofs
      assert((lump.filelen % sizeof_bsp_plane) == 0)
      let nplanes = lump.filelen / sizeof_bsp_plane

      planes = vector_capacity([], nplanes)
      for(nplanes) n:
         push(planes, read_plane(lump, n))

      assert(D.offset == (lump.fileofs + lump.filelen))

   private def load_vertexes(lump):
      let vtx_sz = 4*3
      D.offset = lump.fileofs
      assert((lump.filelen % vtx_sz) == 0)
      let nvtx = lump.filelen / vtx_sz

      vertexes = []
      for(nvtx):
         push(vertexes, D.read_vertex3f())

   private def read_face(lump):
      if (D.offset + sizeof_bsp_face) > lump.next:
         return "EOF reading face @ {D.offset}" from parse
      let plane = D.read_short()
      let side = D.read_short()
      let fedge = D.read_int32()
      let nedges = D.read_short()
      let texinfo = D.read_short()
      let styles = substring(D.data, D.offset, 4)
      D.offset += 4
      let loff = D.read_int32()
      return bsp_face{plane, side, fedge, nedges, texinfo, styles, loff}

      
   private def read_plane(lump, n) -> bsp_plane:
      if (D.offset + sizeof_bsp_plane) > lump.next:
         return "EOF reading plane {n} @ {D.offset}" from parse

      let normal = D.read_vertex3f()
      let dist = D.read_float32()
      let ty = D.read_int32()
      return bsp_plane{normal, dist, ty}

   private def read_lump() -> bsp_lump:
      let ov = D.read_int32()
      let ol = D.read_int32()
      return bsp_lump{ov, ol}

   def dump_debug():
      let oldpd = set_print_decimals(2)
      print("BSP version {version}")
      for(lump_toc) lump, lname:
         print("\tlump {lump_to_name[lname]}\t\t{lump.fileofs}, {lump.filelen}")
      print("#planes: {length(planes)}")
      for(planes) p:
         print("\t{p.desc()}")

      print("#vertexes {length(vertexes)}")
      for(vertexes) v:
         print("\t({v.x}, {v.y}, {v.z})")

      print("#faces {length(faces)}")
      for(faces) face:
         print("\t{face.desc()}")

      print("#edges {length(edges)}")
      for(edges) ed:
         print("\t{ed.x} -> {ed.y}")

      print("#texinfo {length(textures)}")
      for(textures) ti, i:
         print("\t{number_to_string(i, 10, 3)} {ti.desc()}")

      print("#surfedges {length(surf_edges)}")
      for(surf_edges) ed:
         print("\t{ed}")

      print("#leaffaces {length(leaf_faces)}")
      for(leaf_faces) lf:
         print("\t{lf}")

      print("#nodes {length(nodes)}")
      for(nodes) nd, i:
         print("\t{number_to_string(i, 10, 3)} {nd.desc()}")

      print("#leaves {length(leaves)}")
      for(leaves) lf, i:
         print("\t{number_to_string(i, 10, 3)} {lf.desc()}")

      print("#clusters {length(viz_index)}")
      for(viz_index) vi:
         print("\t{vi.desc()}")

      print("#brush sides {length(brush_sides)}")
      for(brush_sides) bs, i:
         print("\t{number_to_string(i, 10, 3)} {bs.desc()}")

      print("#brushes {length(brushes)}")
      for(brushes) br, i:
         print("\t{number_to_string(i, 10, 3)} {br.desc()}")

      print("#leaf brushes {length(leaf_brushes)}")
      for(leaf_brushes) b, i:
         print("\t{number_to_string(i, 10, 3)} {b}")

      print("#models {length(models)}")
      for(models) md:
         print("\t{md.desc()}")

      print("entities {substring(D.data, lump_toc[lump_entities].fileofs, lump_toc[lump_entities].filelen)}")

      set_print_decimals(oldpd)


// Tests for overlap of the standard mins, maxs bounding box formulation.
def aabb_overlaps(mins_a, maxs_a, mins_b, maxs_b) -> bool:
   if (maxs_a < mins_b) != vec3{false, false, false}:
      return false
   if (mins_a > maxs_b) != vec3{false, false, false}:
      return false

   return true

def aabb_contains_point(mins, maxs, pt) -> bool:
   return (pt >= mins) == vec3{true, true, true} and (pt <= maxs) == vec3{true, true, true}

// Parses an entity string that presumably came from lump_entities.
// Calls body("", "") at the start of a a new entity, and then 
// body("key", "value") for each key value pair. 
def parse_entities(buf: string, body) -> string?:
   let L = lex_base{buf: buf, srcname: "bsp entities"}
   L.skip_ws()

   def report(msg):
      print("OOF {L.p} {L.buf}")
      return L.format_error("parse_entities", msg) from parse_entities
      

   while L.chars_left() and L.char() != 0:
      L.skip_ws()
      L.expect('{') msg:
         report(msg)

      body("", "")
      L.skip_ws()
      while L.chars_left() and L.char() != '}':
         let key = L.expect_string() msg:
            report(msg)
         L.skip_ws()
         let val = L.expect_string() msg:
            report(msg)
         body(key, val)
         L.skip_ws()

      L.expect('}') msg:
            report(msg)
      L.skip_ws()

   return nil


// Given an array of nodes and an array of leaf surfaces, and a point, 
// returns the (parent branch index, leaf index) that contains the point.
def bsp_branch_containing_point(nodes, planes, pt: float3, start_node = 0) -> int, int:
   var nd = start_node
   var nxt = nd
   while true:
      let norm = planes[nodes[nd].plane_num].normal
      let d    = planes[nodes[nd].plane_num].dist
      let prod = dot(pt, norm) - d

      if prod > 0.0:
         nxt = nodes[nd].children[0]
      else:
         nxt = nodes[nd].children[1]

      if nxt < 0:
         return nd, -(nxt+1)
      else:
         nd = nxt
         
// Loads wal file header.
private def load_miptex(D: binary_editor) -> bsp_miptex:
   let name = D.read_string(32)
   let w = D.read_uint32()
   let h = D.read_uint32()
   let offsets = D.read_vertex4ui32()
   let aname = D.read_string(32)
   let flags = D.read_int32()
   let contents = D.read_int32()
   let value = D.read_int32()

   return bsp_miptex{name, w, h, offsets, aname, flags, contents, value}
   

// Helper - unconditionally loads mip level 0 of the given .wal file.
// Returns nil if the file could not be read or parsed.
def load_image_wal(name: string) -> bsp_image?:
   let data = read_file(name, 0)
   if data != nil:
      let D = binary_editor{data: data, offset: 0}
      let hdr = load_miptex(D)
      let start = hdr.offsets[0]
      let len = hdr.width*hdr.height
      let px = substring(data, start, len)
      return bsp_image{int2{hdr.width, hdr.height}, px}
   else:
      return nil

