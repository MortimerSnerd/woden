import core.quat
import core.matrix

import data.binary
import color
import std
import vec

private let IQM_MAGIC = "INTERQUAKEMODEL"

class iqm_header:
   version:           int = 0
   filesize:          int = 0
   flags:             int = 0
   num_text:          int = 0
   ofs_text:          int = 0
   num_meshes:        int = 0
   ofs_meshes:        int = 0
   num_vertexarrays:  int = 0
   num_vertexes:      int = 0
   ofs_vertexarrays:  int = 0
   num_triangles:     int = 0
   ofs_triangles:     int = 0
   ofs_adjacency:     int = 0
   num_joints:        int = 0
   ofs_joints:        int = 0
   num_poses:         int = 0
   ofs_poses:         int = 0
   num_anims:         int = 0
   ofs_anims:         int = 0
   num_frames:        int = 0
   num_framechannels: int = 0
   ofs_frames:        int = 0
   ofs_bounds:        int = 0
   num_comment:       int = 0
   ofs_comment:       int = 0
   num_extensions:    int = 0
   ofs_extensions:    int = 0

   def parse_header(D: binary_editor) -> string?:
      D.offset = 0
      let magic = D.read_string(16)

      if magic != IQM_MAGIC:
         return "iqm_header: bad magic {magic}"

      version = D.read_uint32()
      if version != 2:
         // I can only deal with v2
         return "iqm_header: unrecognized version {version}"

      filesize = D.read_uint32()
      flags    = D.read_uint32()
      num_text = D.read_uint32()
      ofs_text = D.read_uint32()
      num_meshes = D.read_uint32()
      ofs_meshes = D.read_uint32()
      num_vertexarrays = D.read_uint32()
      num_vertexes = D.read_uint32()
      ofs_vertexarrays = D.read_uint32()
      num_triangles = D.read_uint32()
      ofs_triangles = D.read_uint32()
      ofs_adjacency = D.read_uint32()
      num_joints = D.read_uint32()
      ofs_joints = D.read_uint32()
      num_poses = D.read_uint32()
      ofs_poses = D.read_uint32()
      num_anims = D.read_uint32()
      ofs_anims = D.read_uint32()
      num_frames = D.read_uint32()
      num_framechannels = D.read_uint32()
      ofs_frames = D.read_uint32()
      ofs_bounds = D.read_uint32()
      num_comment = D.read_uint32()
      ofs_comment = D.read_uint32()
      num_extensions = D.read_uint32()
      ofs_extensions = D.read_uint32()

      return nil

   def write(D: binary_editor):
      D.write_string0(IQM_MAGIC)
      D.write_uint32(version)
      D.write_uint32(filesize)
      D.write_uint32(flags)
      D.write_uint32(num_text)
      D.write_uint32(ofs_text)
      D.write_uint32(num_meshes)
      D.write_uint32(ofs_meshes)
      D.write_uint32(num_vertexarrays)
      D.write_uint32(num_vertexes)
      D.write_uint32(ofs_vertexarrays)
      D.write_uint32(num_triangles)
      D.write_uint32(ofs_triangles)
      D.write_uint32(ofs_adjacency)
      D.write_uint32(num_joints)
      D.write_uint32(ofs_joints)
      D.write_uint32(num_poses)
      D.write_uint32(ofs_poses)
      D.write_uint32(num_anims)
      D.write_uint32(ofs_anims)
      D.write_uint32(num_frames)
      D.write_uint32(num_framechannels)
      D.write_uint32(ofs_frames)
      D.write_uint32(ofs_bounds)
      D.write_uint32(num_comment)
      D.write_uint32(ofs_comment)
      D.write_uint32(num_extensions)
      D.write_uint32(ofs_extensions)

   def debug_string(ind: int):
      return refvalue_debug_string(this, ind)

enum iqm_type:
   iqm_position
   iqm_texcoord
   iqm_normal
   iqm_tangent
   iqm_blend_indexes
   iqm_blend_weights
   iqm_color
   iqm_custom = 0x10

enum iqm_format:
   iqm_byte
   iqm_ubyte
   iqm_short
   iqm_ushort
   iqm_int
   iqm_uint
   iqm_half
   iqm_float
   iqm_double

class iqm_vertexarray:
   type   = iqm_position
   flags  = 0
   format = iqm_float
   size   = 0
   offset = 0

   def read(D: binary_editor):
      type = iqm_type(D.read_uint32())
      flags = D.read_uint32()
      format = iqm_format(D.read_uint32())
      size = D.read_uint32()
      offset = D.read_uint32()

   def write(D: binary_editor):
      D.write_uint32(type)
      D.write_uint32(flags)
      D.write_uint32(format)
      D.write_uint32(size)
      D.write_uint32(offset)

   def debug_string(ind: int):
      let i1 = INDENT(ind)
      let i2 = INDENT(ind+4)
      var rv = "{i1}iqm_vertexarray{{\n"
      rv += "{i2}type: {type},\n"
      rv += "{i2}flags: {flags},\n"
      rv += "{i2}format: {format},\n"
      rv += "{i2}size: {size},\n"
      rv += "{i2}offset: {offset}\n"
      rv += "{i1}}}"
      return rv

class iqm_extension:
    name = 0
    num_data = 0
    ofs_data = 0
    ofs_extensions = 0

    // Not a field in the file, the bytes of the extension data.
    // We don't know what this is, a caller might.
    data = ""

    // Includes the byte data that comes after the header.
    def written_size():
       return 4*4 + length(data)

    def read(D: binary_editor):
        name = D.read_uint32()
        num_data = D.read_uint32()
        ofs_data = D.read_uint32()
        ofs_extensions = D.read_uint32()
        let save = D.offset
        D.offset = ofs_data
        data = D.read_bytes(num_data)
        D.offset = save

    def write(D: binary_editor):
        D.write_uint32(name)
        assert(num_data == length(data))
        D.write_uint32(num_data)
        let calc_ofs = D.offset + 4*2  // after this header
        D.write_uint32(calc_ofs)
        D.write_uint32(ofs_extensions)
        D.write_string(data)

    def debug_string(ind: int):
       let i1 = INDENT(ind)
       let i2 = INDENT(ind+4)
       var rv = "{i1}iqm_extension{{\n"
       rv += "{i2}name: {name},\n"
       rv += "{i2}num_data: {num_data},\n"
       rv += "{i2}ofs_data: {ofs_data},\n"
       rv += "{i2}ofs_extensions: {ofs_extensions}\n"
       rv += "{i1}}}"
       return rv

class iqm_mesh:
   name = 0
   material = 0
   first_vertex = 0
   num_vertexes = 0
   first_triangle = 0
   num_triangles = 0

   def read(D: binary_editor):
      name = D.read_uint32()
      material = D.read_uint32()
      first_vertex = D.read_uint32()
      num_vertexes = D.read_uint32()
      first_triangle = D.read_uint32()
      num_triangles  = D.read_uint32()

   def write(D: binary_editor):
      D.write_uint32(name)
      D.write_uint32(material)
      D.write_uint32(first_vertex)
      D.write_uint32(num_vertexes)
      D.write_uint32(first_triangle)
      D.write_uint32(num_triangles)

   def debug_string(ind: int):
      let i1 = INDENT(ind)
      let i2 = INDENT(ind+4)
      var rv = "{i1}iqm_mesh{{\n"
      rv += "{i2}name: {name},\n"
      rv += "{i2}material: {material},\n"
      rv += "{i2}first_vertex: {first_vertex},\n"
      rv += "{i2}num_vertexes: {num_vertexes},\n"
      rv += "{i2}first_triangle: {first_triangle},\n"
      rv += "{i2}num_triangles: {num_triangles}\n"
      rv += "{i1}}}"
      return rv

class iqm_joint:
   name = 0
   parent = 0
   translate = float3_0
   rotate = quat{float3_0, 0.0}
   scale = float3_0

   def read(D: binary_editor):
      name = D.read_uint32()
      parent = D.read_int32()
      translate = D.read_vertex3f()
      let v = D.read_vertex3f()
      let w = D.read_float32()
      rotate = quat{v, w}
      scale = D.read_vertex3f()

   def write(D: binary_editor):
      D.write_uint32(name)
      D.write_int32(parent)
      D.write_vertex3f(translate)
      D.write_vertex3f(rotate.v)
      D.write_float32(rotate.w)
      D.write_vertex3f(scale)

   def debug_string(ind: int):
      let i1 = INDENT(ind)
      let i2 = INDENT(ind+4)
      var rv = "{i1}iqm_joint{{\n"
      rv += "{i2}parent: {parent},\n"
      rv += "{i2}translate: {translate},\n"
      rv += "{i2}rotate: {rotate},\n"
      rv += "{i2}scale: {scale}\n"
      rv += "{i1}}}"
      return rv


class iqm_frame_transform:
   // not explicit in the format, but built up from frame animation channel data.
   rotation    = quat{float3_z, 0.0}
   translation = float3_0
   scale       = float3_1
   frame_ix    = -1
   pose_ix     = -1

   def debug_string(ind: int):
      let i1 = INDENT(ind)
      let i2 = INDENT(ind+4)
      var rv = "{i1}iqm_frame_transform{{\n"
      rv += "{i2}rotation: {rotation},\n"
      rv += "{i2}translation: {translation},\n"
      rv += "{i2}scale: {scale}\n"
      rv += "{i1}}}"
      return rv
       
class iqm_pose:
   parent         = -1
   mask           = 0
   channel_offset = [] :: float // 10
   channel_scale  = [] :: float

   def read(D: binary_editor):
      parent = D.read_int32()
      mask = D.read_uint32()
      channel_offset = []
      for(10):
         push(channel_offset, D.read_float32())
      for(10):
         push(channel_scale, D.read_float32())

   def write(D: binary_editor):
      D.write_int32(parent)
      D.write_uint32(mask)
      assert length(channel_offset) == 10
      assert length(channel_scale) == 10
      for(channel_offset) co:
         D.write_float32(co)
      for(channel_scale) cs:
         D.write_float32(cs)

   def debug_string(ind: int):
      let i1 = INDENT(ind)
      let i2 = INDENT(ind+4)
      var rv = "{i1}iqm_pose{{\n"
      rv += "{i2}parent: {parent},\n"
      rv += "{i2}mask: {mask},\n"
      rv += "{i2}channel_offset: {channel_offset},\n"
      rv += "{i2}channel_scale: {channel_scale}\n"
      rv += "{i1}}}"
      return rv

class iqm_anim:
   name        = 0
   first_frame = 0
   num_frames  = 0
   frame_rate  = 0.0
   flags       = 0

   def read(D: binary_editor):
      name = D.read_uint32()
      first_frame = D.read_uint32()
      num_frames = D.read_uint32()
      frame_rate = D.read_float32()
      flags = D.read_uint32()

   def write(D: binary_editor):
      D.write_uint32(name)
      D.write_uint32(first_frame)
      D.write_uint32(num_frames)
      D.write_float32(frame_rate)
      D.write_uint32(flags)   

   def debug_string(ind: int):
      let i1 = INDENT(ind)
      let i2 = INDENT(ind+4)
      var rv = "{i1}iqm_anim{{\n"
      rv += "{i2}name: {name},\n"
      rv += "{i2}first_frame: {first_frame},\n"
      rv += "{i2}num_frames: {num_frames},\n"
      rv += "{i2}frame_rate: {frame_rate},\n"
      rv += "{i2}flags: {flags},\n"
      rv += "{i1}}}"
      return rv

class iqm_bounds:
   bbmin = float3_0
   bbmax = float3_0
   xyradius = 0.0
   radius = 0.0

   def read(D: binary_editor):
      bbmin = D.read_vertex3f()
      bbmax = D.read_vertex3f()
      xyradius = D.read_float32()
      radius = D.read_float32()

   def write(D: binary_editor):
      D.write_vertex3f(bbmin)
      D.write_vertex3f(bbmax)
      D.write_float32(xyradius)
      D.write_float32(radius)      

   def debug_string(ind: int):
      let i1 = INDENT(ind)
      let i2 = INDENT(ind+4)
      var rv = "{i1}iqm_bounds{{\n"
      rv += "{i2}bbmin: {bbmin},\n"
      rv += "{i2}bbmax: {bbmax},\n"
      rv += "{i2}xyradius: {xyradius},\n"
      rv += "{i2}radius: {radius}\n"
      rv += "{i1}}}"
      return rv


private struct string_ent:
   offset: int
   val: string

// Not in the format, just a container for vertex data.
// Items left empty were not present in the file.
class iqm_vertexes:
   pos = [] :: float3
   norm = [] :: float3
   tangent = [] :: float4
   texcoord = [] :: float2
   blend_indexes = ""    // 4 bytes per vertex
   blend_weights = ""    // 4 bytes per vertex 
   color = [] :: color

   def write(D: binary_editor, vat: iqm_type):
      if vat == iqm_position: 
         for(pos) p:
            D.write_vertex3f(p)
      elif vat == iqm_texcoord:
         for(texcoord) tc:
            D.write_vertex2f(tc)
      elif vat == iqm_normal:
         for(norm) n:
            D.write_vertex3f(n)
      elif vat == iqm_tangent:
         for(tangent) t:
            D.write_vertex4f(t)
      elif vat == iqm_blend_indexes:
         D.write_string(blend_indexes)
      elif vat == iqm_blend_weights:
         D.write_string(blend_weights)
      elif vat == iqm_color:
         for(color) c:
            D.write_byte(int(c.red*255.0))
            D.write_byte(int(c.green*255.0))
            D.write_byte(int(c.blue*255.0))
            D.write_byte(int(c.alpha*255.0))
      else:
         fatal("iqm_vertexes::write - unimplemented for vertex type {vat}")

   // Returns size when it is written.  In memory size is larger because 64bit vs 32bit.
   def byte_size():
      return length(pos)*3*4 + length(norm)*3*4 + length(tangent)*4*4 + length(texcoord)*2*4 + length(blend_indexes) + length(blend_weights) + length(color)*4*4

   def print_summary():
      print("pos={length(pos)} norm={length(norm)} tangent={length(tangent)} texcoord={length(texcoord)} blend_indexes={length(blend_indexes)} blend_weights={length(blend_weights)} color={length(color)}")

   def debug_print(ind: int):
      let ind1 = INDENT(ind)
      let ind2 = INDENT(ind+4)

      def parr(name, arr):
         if length(arr):
            print("{ind1}{name}:")
            if arr is string:
               print("{ind2}....")
            else:
               for(arr) p:
                  print("{ind2}{p}")

      parr("pos", pos)
      parr("normal", norm)
      parr("tangent", tangent)
      parr("texcoord", texcoord)
      parr("blend_indexes", blend_indexes)
      parr("blend_weights", blend_weights)
      parr("color", color)

class iqm_file:
   D = binary_editor{}
   hdr = iqm_header{}
   joints = [] :: iqm_joint
   stringtab = [] :: string_ent
   meshes = [] :: iqm_mesh
   varrays = [] :: iqm_vertexarray
   triangles = [] :: int      // 3 indices per triangle
   adjacency = [] :: int3    // Triangle indices
   poses = [] :: iqm_pose
   anims = [] :: iqm_anim
   bounds = [] :: iqm_bounds
   frames = [] :: iqm_frame_transform
   frame_mults = [] :: int  // Framedata shorts
   vertices = iqm_vertexes{}
   extensions = [] :: iqm_extension
   loaded = false

   def parse_iqm(bytes: string) -> string?:
      D.data = bytes
      let err = hdr.parse_header(D)
      if err:
         return err
      else:
         read_stringtab()
         read_meshes()
         read_joints()
         read_varrays()
         read_triangles()
         read_adjacency()
         read_poses()
         read_anims()
         read_frames()
         read_bounds()
         read_vertices()
         //TODO comments
         read_extensions()
         loaded = true

         return nil

   def debug_print(ind: int):
      let inds = repeat_string(" ", ind)
      let inds2 = repeat_string(" ", ind + 4)

      print("{inds}iqm_file{{")
      print("{inds2}meshes:")
      for(meshes) m:
         print("{m.debug_string(ind + 8)}")

      print("{inds2}joints:")
      for(joints) j:
         print(j.debug_string(ind + 8))

      print("{inds2}vertexarrays:")
      for(varrays) va:
         print(va.debug_string(ind + 8))

      print("{inds2}triangle indices:")
      for(triangles) t:
         print("{INDENT(ind+8)}{t}")
         
      print("{inds2}adjacency:")
      for(adjacency) t:
         print("{INDENT(ind+8)}{t[0]} : {t[1]} : {t[2]}")

      print("{inds2}poses:")
      for(poses) p:
         print(p.debug_string(ind + 8))

      print("{inds2}anims:")
      for(anims) a:
         print(a.debug_string(ind+8))

      print("{inds2}bounds:")
      for(bounds) b:
         print(b.debug_string(ind+8))

      print("{inds2}frames:")
      for(frames):
         print(_.debug_string(ind+8))

      print("{inds2}extensions:")
      for(extensions):
         print(_.debug_string(ind+8))

      vertices.debug_print(ind+4)

      print("{inds}}}")

   def read_extensions():
       var off = hdr.ofs_extensions

       while off != 0:
           D.offset = off
           let ex = iqm_extension{}
           ex.read(D)
           push(extensions, ex)
           off = ex.ofs_extensions

   def read_vertices():
      let vtxs = iqm_vertexes{}
      let all_vatypes = [iqm_position, iqm_texcoord, iqm_normal, iqm_tangent, iqm_blend_indexes, iqm_blend_weights, iqm_color]

      // Lots of asserts here, because we're initially not interested in doing a 
      for(varrays) va:
         D.offset = va.offset
         switch va.type:
            case iqm_position:
               assert va.format == iqm_float and va.size == 3
               for(hdr.num_vertexes):
                  push(vtxs.pos, D.read_vertex3f())
            case iqm_normal:
               assert va.format == iqm_float and va.size == 3
               for(hdr.num_vertexes):
                  push(vtxs.norm, D.read_vertex3f())
            case iqm_tangent:
               assert va.format == iqm_float and va.size == 4
               for(hdr.num_vertexes):
                  push(vtxs.tangent, D.read_vertex4f())
            case iqm_texcoord:
               assert va.format == iqm_float and va.size == 2
               for(hdr.num_vertexes):
                  push(vtxs.texcoord, D.read_vertex2f())
            case iqm_blend_indexes:
               assert va.format == iqm_ubyte and va.size == 4
               vtxs.blend_indexes = D.read_bytes(hdr.num_vertexes*4)
            case iqm_blend_weights:
               assert va.format == iqm_ubyte and va.size == 4
               vtxs.blend_weights = D.read_bytes(hdr.num_vertexes*4)
            case iqm_color:
               assert va.format == iqm_ubyte and va.size == 4
               for(hdr.num_vertexes):
                  let r = float(D.read_byte())
                  let g = float(D.read_byte())
                  let b = float(D.read_byte())
                  let a = float(D.read_byte())
                  push(vtxs.color, color{r/255.0, g/255.0, b/255.0, a/255.0})
            case iqm_custom:
               pass()

      // Do default colors, because our phong shaders depend on a vertex
      // color being set.
      if length(vtxs.color) == 0:
         vtxs.color = map(vtxs.pos): color{1.0, 1.0, 1.0, 1.0}

      vertices = vtxs

   // Based on Lobster's glloadiqm.c::loadiqmanims
   // Requires poses to already be read in.
   def read_frames():
      D.offset = hdr.ofs_frames
      frames = map(hdr.num_frames*hdr.num_poses): iqm_frame_transform{}
      for(hdr.num_frames) i:
         for(hdr.num_poses) j:
            let p = poses[j]
            let trs = []
            for(10) k:
               push(trs, p.channel_offset[k])
               if p.mask&(1 << k):
                  let mult = D.read_ushort()
                  push(frame_mults, mult)
                  trs[k] += float(mult) * p.channel_scale[k]
            
            let rot = quat{float3{trs[3], trs[4], trs[5]}, trs[6]}.normalize_q()
            let scale = float3{trs[7], trs[8], trs[9]}
            let trans = float3{trs[0], trs[1], trs[2]}
            frames[i*hdr.num_poses + j] = iqm_frame_transform{rotation: rot, 
                                                              translation: trans, 
                                                              scale: scale, 
                                                              frame_ix: i,
                                                              pose_ix: j}

   def read_bounds():
      D.offset = hdr.ofs_bounds
      for(hdr.num_frames):
         let b = iqm_bounds{}
         b.read(D)
         push(bounds, b)

   def read_anims():
      D.offset = hdr.ofs_anims
      for(hdr.num_anims):
         let a = iqm_anim{}
         a.read(D)
         push(anims, a)

   def read_poses():
      D.offset = hdr.ofs_poses
      for(hdr.num_poses):
         let p = iqm_pose{}
         p.read(D)
         push(poses, p)

   def read_triangles():
      D.offset = hdr.ofs_triangles
      for(hdr.num_triangles):
         push(triangles, D.read_uint32())
         push(triangles, D.read_uint32())
         push(triangles, D.read_uint32())

   def read_adjacency():
      D.offset = hdr.ofs_adjacency
      for(hdr.num_triangles):
         //NB iqm.h has uint, but it also uses 0xffffffff as a sentinel.
         //   So just assume we don't have enough triangles to overflow
         //   32bit signed.
         push(adjacency, D.read_vertex3i())

   def read_varrays():
      D.offset = hdr.ofs_vertexarrays
      for(hdr.num_vertexarrays):
         let va = iqm_vertexarray{}
         va.read(D)
         push(varrays, va)

   def read_joints():
      D.offset = hdr.ofs_joints
      for(hdr.num_joints):
         let j = iqm_joint{}
         j.read(D)
         push(joints, j)

   def read_meshes():
      D.offset = hdr.ofs_meshes
      for(hdr.num_meshes):
         let m = iqm_mesh{}
         m.read(D)
         push(meshes, m)

   // Read in offset/string pairs for easier name lookup via
   // string_to_offset.
   private def read_stringtab():
      D.offset = hdr.ofs_text

      while D.offset < hdr.ofs_text+hdr.num_text:
         let start = D.offset
         let s = D.read_string0()
         push(stringtab, string_ent{start - hdr.ofs_text, s})

   // Returns the string for an offset.  Will fail if the offset doesn't
   // exist, so only feed it from iqm data.
   def string_for_offset(o: int) -> string:
      return stringtab[find(stringtab): _.offset == o].val

   // Returns the string offset of the given string, or -1 if none found.
   def string_to_offset(s: string):
      let i = find(stringtab): _.val == s
      if i >= 0:
         return stringtab[i].offset
      else:
         return -1

   def find_joint(name_ofs: int) -> int:
      return find(joints): name_ofs == _.name

   def find_joint(name: string) -> int:
      return find_joint(string_to_offset(name))

   // Returns a [[xyz]] with one array per joint, containing
   // all of the vertices that are wholly owned by the bone.  (ie, 
   // we don't count vertices that are weighted between mulitple bones).
   def partition_vertices_by_joints() -> [[float3]]:
      let rv = map(hdr.num_joints): []
      for(length(vertices.pos)) i: 
         if vertices.blend_weights[i*4] == 255:
            push(rv[vertices.blend_indexes[i*4]], vertices.pos[i])
      return rv

   // Writes out the current iqm_file as a byte string.
   def write_iqm() -> string:
      D.data = ensure_size("", guess_file_size(), 0)
      // Skip the header, we write it as the last step.
      D.offset = 16 + 4*27
      pad_to_4byte()

      write_stringtab()
      write_joints()
      write_meshes()
      write_vertexarrays()
      write_triangles()
      write_adjacency()
      write_poses()
      write_anims()
      write_bounds()
      write_frames()
      write_extensions()

      // Go back and write updated header.
      hdr.filesize = D.offset
      D.offset = 0
      write_header()
      return substring(D.data, 0, hdr.filesize)

   private def write_extensions():
      pad_to_4byte()
      hdr.num_extensions, hdr.ofs_extensions = array_current_offset(anims)

      // Calculate sizes so we can write out the link fields
      var ep = D.offset
      let locs = []
      for(extensions) ex:
         push(locs, ep)
         ep += ex.written_size()
         let m = ep % 4
         if m != 0:
            ep += 4-m

      for(extensions) ex, i:
         if i < length(extensions)-1:
            ex.ofs_extensions = locs[i+1]
         else:
            ex.ofs_extensions = 0
         ex.write(D)
         // re-pad, because there's no guarantee we're dword aligned
         // with the extension data
         pad_to_4byte()

   private def write_frames():
      pad_to_4byte()
      //TODO goofy setting this from length of "bounds" even if it matches up
      hdr.num_frames = length(bounds)
      hdr.num_framechannels = length(frame_mults) / hdr.num_frames
      hdr.ofs_frames = if length(frame_mults) == 0: 0 else: D.offset
      for(frame_mults) m:
         D.write_uint16(m)

   private def write_bounds():
      pad_to_4byte()
      hdr.ofs_bounds = D.offset
      for(bounds) b:
         b.write(D)

   private def write_anims():
      pad_to_4byte()
      hdr.num_anims, hdr.ofs_anims = array_current_offset(anims)
      for(anims) a:
         a.write(D)

   private def write_poses():
      pad_to_4byte()
      hdr.num_poses, hdr.ofs_poses = array_current_offset(poses)
      for(poses) p:
         p.write(D)

   private def write_adjacency():
      pad_to_4byte()
      hdr.ofs_adjacency = D.offset
      for(adjacency) a:
         D.write_vertex3i(a)

   private def write_triangles():
      pad_to_4byte()
      assert length(triangles) % 3 == 0
      if length(triangles) > 0:
         hdr.num_triangles = length(triangles)/3
         hdr.ofs_triangles = D.offset
      else:
         hdr.num_triangles = 0
         hdr.ofs_triangles = 0
      for(triangles) i:
         D.write_uint32(i)

   private def write_vertexarrays():
      // Format requires these to be ordered by type
      qsort_in_place(varrays) a, b: a.type < b.type

      // First, write out the vertex data and record the offsets of where
      // we put it.
      let offsets = []
      for(varrays) va:
         pad_to_4byte()
         push(offsets, D.offset)
         vertices.write(D, va.type)
         
      pad_to_4byte()
      hdr.num_vertexarrays, hdr.ofs_vertexarrays = array_current_offset(varrays)
      for(varrays) va, i:
         va.offset = offsets[i]
         va.write(D)

   private def write_meshes():
      pad_to_4byte()
      hdr.num_meshes, hdr.ofs_meshes = array_current_offset(meshes)
      for(meshes) m:
         m.write(D)

   private def write_stringtab():
      pad_to_4byte()
      hdr.ofs_text = D.offset
      for(stringtab) se:
         D.write_string0(se.val)
      hdr.num_text = D.offset - hdr.ofs_text

   private def write_joints():
      pad_to_4byte()
      hdr.num_joints, hdr.ofs_joints = array_current_offset(joints)
      for(joints) j:
         j.write(D)

   // Helper that sets returns the count, and current offset 
   // for the given array, maintaining the rule that an offset of 0
   // means "not present".
   private def array_current_offset(arr):
      if length(arr) == 0:
         return 0, 0
      else:
         return length(arr), D.offset

   // Assumes header class has already been updated with correct values.
   private def write_header():
      hdr.write(D)

   private def pad_to_4byte():
      while D.offset % 4 != 0:
         D.write_byte(0)

   private def guess_file_size():
      return vertices.byte_size() * 3 / 2

   // Adds a string to the stringtable if it does not already exist, and returns the
   // resultant offset. 
   def add_string(s: string) -> int:
      if length(stringtab) == 0:
         // First entry is always a zero length string.
         push(stringtab, string_ent{0, ""})
        
      let i = find(stringtab): _.val == s
      if i >= 0:
         return stringtab[i].offset
      else:
         let o = next_stringtab_offset()
         push(stringtab, string_ent{o, s})
         return o

   private def next_stringtab_offset():
      var o = 0
      for(stringtab) se:
         o += length(se.val) + 1
      return o

private def refvalue_debug_string(x, ind = 0):
   let inds = repeat_string(" ", ind)
   let inds2 = repeat_string(" ", ind+4)
   var rv = "{inds}{type_string(x)}{{\n"
   let nfields = type_field_count(x)
   for(type_field_count(x)) i:
      let c = if i == nfields-1: "" else: ","
      rv += "{inds2}{type_field_name(x, i)}: {type_field_value(x, i)}{c}\n"
   rv += "{inds}}}"
   return rv

private def INDENT(x):
   return repeat_string(" ", x)

def read_iqm_file(fname: string) -> string?, iqm_file:
   let f = iqm_file{}
   let b = read_file(fname)
   if b:
      let err = f.parse_iqm(b)
      return err, f
   else:
      return "read_iqm_file: could not open {fname}", f

// Generates frame transforms using the same method lobster does. 
def gen_iqm_frame_transforms(f: iqm_file):
   let baseframe = map(f.joints) j: iqm_rotation_scale_trans(j.rotate.normalize_q(), j.scale, j.translate)
   let inversebaseframe = map(baseframe): iqm_invertortho(_)
   for(length(baseframe)) i:
      let j = f.joints[i]
      if j.parent >= 0:
         baseframe[i] = baseframe[j.parent] * baseframe[i]
         inversebaseframe[i] = inversebaseframe[i] * inversebaseframe[j.parent]
      
   let frame_mats = map(f.frames): iqm_rotation_scale_trans(_.rotation, _.scale, _.translation)
   for(frame_mats) fr, z:
      let frame_ix = f.frames[z].frame_ix
      let pose_ix = f.frames[z].pose_ix
      let p = f.poses[pose_ix]
      var m = fr
 
      if p.parent >= 0:
         m = baseframe[p.parent] * m * inversebaseframe[pose_ix]
      else:
         m = m * inversebaseframe[pose_ix]

      if f.joints[pose_ix].parent >= 0:
         m = frame_mats[frame_ix*f.hdr.num_poses + f.joints[pose_ix].parent] * m

      assert (frame_ix*f.hdr.num_poses + pose_ix) == z
      frame_mats[z] = m
      // works for t-pose
      //frame_mats[z] = mat3x4{float4_x, float4_y, float4_z}

   return frame_mats

// Turns an array of matrices into a list of [xyzw], one per frame, that 
// can be passed to a shader as a uniform array.
def iqm_to_uniform_array(f: iqm_file, mats: [mat3x4]) -> [[float4]]:
   let hdr = f.hdr
   var i = 0
   let rv = map(hdr.num_frames): [] :: float4
   
   for(hdr.num_frames) fno:
      for(hdr.num_poses):
         let m = mats[i]
         push(rv[fno], m.col0)
         push(rv[fno], m.col1)
         push(rv[fno], m.col2)
         i++
   return rv

// Reverse of iqm_to_uniform_array for single sets of frame transformations.
// NB this is ugly consequence of having mat classes for calcs, but having
// to flatten into an arary of float4 for the shader.
def iqm_uniform_array_to_mats(arr: [float4]) -> [mat3x4]:
    let rv = []
    for(length(arr)/3) i:
        push(rv, mat3x4{arr[i*3+0], arr[i*3+1], arr[i*3+2]})
    return rv

// Produces an array of frame transforms for a model that are identity
// transforms.  (so, probably a T pose).
def iqm_get_identity_frame_transform(f: iqm_file) -> [float4]:
   let rv = vector_capacity([], f.hdr.num_frames * 3)
   for(f.hdr.num_frames):
      push(rv, float4_x)
      push(rv, float4_y)
      push(rv, float4_z)
   return rv



