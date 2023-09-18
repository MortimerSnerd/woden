// Helper for building meshes. 
import color
import core.algs
import vec

class mesh_builder:
   pos3:    [float3]  = []
   tc1:     [float2]   = []
   tc2:     [float2]   = []
   normals: [float3]  = []
   colors:  [color] = []
   indices: [int]    = []

   // Parameters optionally used by users of mesh_builder, or
   // by the utility functions.
   //

   // Keeps track of world texture position in 3d space.
   tx_pos = float2_0

   // World to texture space factor
   wld_to_tx = 1.0

   // Clears all of the accumulated data.
   def reset():
      pos3    = []
      tc1     = []
      tc2     = []
      normals = []
      colors  = []
      indices = []

   def is_empty() -> bool:
      return length(pos3) == 0

   def has_vertices() -> bool:
      return length(pos3) > 0

   // Returns estimate of size of data that would need to be sent over to the
   // gpu.
   def buffer_size():
      return length(pos3)*12 + length(tc1)*8 + length(tc2)*8 + length(normals)*12 + length(colors)*16 + length(indices)*4

   // Creates a new mesh not using indices given the
   // 'fmt' format string.  (see gl.new_mesh for syntax
   // of format string).  Does not clear the accumulated
   // mesh data.
   def make_mesh(fmt: string) -> resource<mesh>:
      return gl.new_mesh(fmt, pos3, colors, normals, tc1, tc2, [])
      
   // Creates a new indexed mesh given the
   // 'fmt' format string.  (see gl.new_mesh for syntax
   // of format string).  Does not clear the accumulated
   // mesh data.  Assumes the mesh was built up with the
   // indexed versions of the mesh helper functions.
   def make_mesh_indexed(fmt: string) -> resource<mesh>:
      assert(length(indices) > 0)
      return gl.new_mesh(fmt, pos3, colors, normals, tc1, tc2, indices)
      
   // Debug output.  Just shows vertex data, doesn't repeat it based
   // on any indices.
   def dump_vertices():
      print("vertex dump")
      for(pos3) p, i:
         var s = "\t{p}"
         if i < length(tc1):
            s += "\ttc1={tc1[i]}"
         if i < length(tc2):
            s += "\ttc2={tc2[i]}"
         if i < length(normals):
            s += "\tn={normals[i]}"
         if i < length(colors):
            s += "\tcol={colors[i]}"
         print(s)

// Fat vertex that has all possible components, with default
// values.  Mainly intended to document the member names we're looking
// for, but could be used to 
struct FATVERT:
   p:  float3  = float3_0
   n:  float3  = float3_0
   t0: float2   = float2_0
   t1: float2   = float2_0
   c:  color = color_black


//
// Vertex structures.
// Should use member naming convention:
//      p: float3        position
//      n: float3        normal
//      t0: float2        tex coords 0
//      t1: float2        tex coords 1
//      c: color       color
//

// Struct for a vertex containing pos, normal and a texcoord.
struct PNT:
   p:  float3
   n:  float3
   t0: float2

   def mknew(s) -> PNT:
      if typeof s is PNT:
         return s
      else:
         return PNT{s.p, s.n, s.t0}

   def put(mb: mesh_builder) -> int:
      let rv = length(mb.pos3)
      push(mb.pos3, p)
      push(mb.normals, n)
      push(mb.tc1, t0)
      return rv

   // Can give a default value for vertex structs that have no texcoords.
   def get_tc0() -> float2:
      return t0

   def get_tc1() -> float2:
      return float2_0

   def get_n() -> float3:
      return n

   def get_c() -> color:
      return color_black

   def with_normal(n1: float3) -> PNT:
      return PNT{p, n1, t0}

   def translated_by(dp: float3) -> PNT:
      return PNT{p+dp, n, t0}

// Just the position
struct P:
   p: float3

   def mknew(s) -> P:
      return P{s.p}

   def put(mb: mesh_builder) -> int:
      let rv = length(mb.pos3)
      push(mb.pos3, p)
      return rv

   // Put with an additional normal.
   def put_with_normal(mb: mesh_builder, norm: float3):
      push(mb.pos3, p)
      push(mb.normals, norm)

   // Can give a default value for vertex structs that have no texcoords.
   def get_tc0() -> float2:
      return float2_0

   def get_tc1() -> float2:
      return float2_0

   def get_n() -> float3:
      return float3_0

   def get_c() -> color:
      return color_black

// Position and color
struct PC:
   p: float3
   c: color

   def mknew(s) -> PC:
      return P{s.p, s.c}

   def put(mb: mesh_builder) -> int:
      let rv = length(mb.pos3)
      push(mb.pos3, p)
      push(mb.colors, c)
      return rv

   // Put with an additional normal.
   def put_with_normal(mb: mesh_builder, norm: float3):
      push(mb.pos3, p)
      push(mb.colors, c)
      push(mb.normals, norm)

   // Can give a default value for vertex structs that have no texcoords.
   def get_tc0() -> float2:
      return float2_0

   def get_tc1() -> float2:
      return float2_0

   def get_n() -> float3:
      return float3_0

   def get_c() -> color:
      return c

// Vertex with just position and texture.
struct PT:
   p: float3
   t0: float2

   def mknew(s) -> PT:
      return PT{s.p, s.t0}

   def put(mb: mesh_builder) -> int:
      let rv = length(mb.pos3)
      push(mb.pos3, p)
      push(mb.tc1, t0)
      return rv

   // Put with an additional normal.
   def put_with_normal(mb: mesh_builder, norm: float3):
      push(mb.pos3, p)
      push(mb.normals, norm)
      push(mb.tc1, t0)

   // Can give a default value for vertex structs that have no texcoords.
   def get_tc0() -> float2:
      return t0

   def get_tc1() -> float2:
      return float2_0

   def get_n() -> float3:
      return float3_0

   def get_c() -> color:
      return color_black

// Vertex with just position and texture and color.
struct PTC:
   p: float3
   t0: float2
   c: color

   def mknew(s) -> PTC:
      return PT{s.p, s.t0, s.c}

   def put(mb: mesh_builder) -> int:
      let rv = length(mb.pos3)
      push(mb.pos3, p)
      push(mb.tc1, t0)
      push(mb.colors, c)
      return rv

   // Put with an additional normal.
   def put_with_normal(mb: mesh_builder, norm: float3):
      push(mb.pos3, p)
      push(mb.normals, norm)
      push(mb.tc1, t0)
      push(mb.colors, c)

   // Can give a default value for vertex structs that have no texcoords.
   def get_tc0() -> float2:
      return t0

   def get_tc1() -> float2:
      return float2_0

   def get_n() -> float3:
      return float3_0

   def get_c() -> color:
      return c


// Vertex with just position and 2 textures.
struct PTT:
   p: float3
   t0: float2
   t1: float2

   def mknew(s) -> PTT:
      return PTT{s.p, s.t0, s.t1}

   def put(mb: mesh_builder) -> int:
      let rv = length(mb.pos3)
      push(mb.pos3, p)
      push(mb.tc1, t0)
      push(mb.tc2, t1)
      return rv

   // Put with an additional normal.
   def put_with_normal(mb: mesh_builder, norm: float3):
      push(mb.pos3, p)
      push(mb.normals, norm)
      push(mb.tc1, t0)
      push(mb.tc2, t1)

   // Can give a default value for vertex structs that have no texcoords.
   def get_tc0() -> float2:
      return t0

   def get_tc1() -> float2:
      return t1

   def get_n() -> float3:
      return float3_0

   def get_c() -> color:
      return color_black

struct PNC:
   p: float3
   n: float3
   c: color

   def mknew(s) -> PNC:
      return PNC{s.p, s.n, s.get_c()}

   def put(mb: mesh_builder) -> int:
      let rv = length(mb.pos3)
      push(mb.pos3, p)
      push(mb.normals, n)
      push(mb.colors, c)
      return rv

   // Put with an additional normal.
   def put_with_normal(mb: mesh_builder, norm: float3):
      push(mb.pos3, p)
      push(mb.normals, norm)
      push(mb.colors, c) 

   // Can give a default value for vertex structs that have no texcoords.
   def get_tc0() -> float2:
      return float2_0

   def get_tc1() -> float2:
      return float2_0

   def get_n() -> float3:
      return n

   def get_c() -> color:
      return c

// and..., Vertex with just position and normal
struct PN:
   p: float3
   n: float3

   def mknew(s) -> PN:
      return PN{s.p, s.n}

   def put(mb: mesh_builder) -> int:
      let rv = length(mb.pos3)
      push(mb.pos3, p)
      push(mb.normals, n)
      return rv

   // Put with an additional normal.
   def put_with_normal(mb: mesh_builder, norm: float3):
      push(mb.pos3, p)
      push(mb.normals, norm)

   // Can give a default value for vertex structs that have no texcoords.
   def get_tc0() -> float2:
      return float2_0

   def get_tc1() -> float2:
      return float2_0

   def get_n() -> float3:
      return n

   def get_c() -> color:
      return color_black

   def translated_by(dp: float3) -> PN:
      return PN{p+dp, n}

   def with_normal(n1: float3) -> PN:
      return PN{p, n1}

// Creates a convex polygon given a CW array of points.
//   
//   0 ---- 1
//   |       \
//   |         2
//   |       /
//   4------3 
//   
//  Produces triangles 210 320 430
def mk_poly(mb: mesh_builder, pts):
   var i = 1
   let last_start = length(pts) - 2

   assert last_start > 1
   while i <= last_start:
      pts[i+1].put(mb)
      pts[i].put(mb)
      pts[0].put(mb)
      i += 1

// Helper for indexed mesh that pushes indices in a 
// triangle fan pattern around a base point.
private def push_poly_fan_indices(mb, last_start, base):
   var i = base + 1
   assert last_start >= 1
   while i <= last_start:
      push(mb.indices, i+1)
      push(mb.indices, i)
      push(mb.indices, base)
      i += 1

// Like mk_poly, but produces indexed mesh.
def mk_poly_indexed(mb: mesh_builder, pts):
   let base = length(mb.pos3)
   let n = pts[0].get_n()

   if is_ccw_winding(pts, n):
       for(pts) p:
          p.put(mb)
   else:
        for_reverse(pts) p:
            p.put(mb)

   push_poly_fan_indices(mb, base + length(pts)-2, base)

// Like mk_poly, but with a uniform normal 
// applied to all vertices.
def mk_poly_flat(mb: mesh_builder, pts, normal: float3):
   var i = 1
   let last_start = length(pts) - 2

   assert last_start > 1
   while i <= last_start:
      pts[i+1].put_with_normal(mb, normal)
      pts[i].put_with_normal(mb, normal)
      pts[0].put_with_normal(mb, normal)
      i += 1
   

// Like mk_poly, but produces indexed mesh.
def mk_poly_flat_indexed(mb: mesh_builder, pts, normal: float3):
   let base = length(mb.pos3)
   if is_ccw_winding(pts, normal):
      for(pts) p:
         p.put_with_normal(mb, normal)
   else:
      for_reverse(pts) p:
         p.put_with_normal(mb, normal)

   push_poly_fan_indices(mb, base + length(pts)-2, base)

private def mk_quad_geom(mb: mesh_builder, start_point, width: float3, height: float3):
   let vtxs = vector_capacity([start_point], 4)
   let tltc = start_point.get_tc0()
   let widths = magnitude(width)
   let heights = magnitude(height)

   push(vtxs, start_point.mknew(PNT{
      p: start_point.p + width, 
      n: start_point.n,
      t0: tltc + float2{mb.wld_to_tx*widths, 0.0}, 
   }))
   push(vtxs, start_point.mknew(PNT{
      p: start_point.p + width + height, 
      n: start_point.n,
      t0: tltc + float2{mb.wld_to_tx*widths, mb.wld_to_tx*heights}, 
   }))
   push(vtxs, start_point.mknew(PNT{
      p: start_point.p + height, 
      n: start_point.n,
      t0: tltc + float2{0.0, mb.wld_to_tx*heights}, 
   }))
   if not is_ccw_winding(vtxs, start_point.n):
      heap_swap(vtxs, 0, 3)
      heap_swap(vtxs, 1, 2)

   return vtxs 

// Builds an arbitrarily oriented quad given a start point, 
// width, height and width_direction vector, and some build
// parameters.  Uses vertex type used for start_point.  Does require start_point
// has a normal.
def mk_quad(mb: mesh_builder, start_point, width: float3, height: float3):
   mk_poly(mb, mk_quad_geom(mb, start_point, width, height))

// Like mk_quad, but builds an indexed mesh.
def mk_quad_indexed(mb: mesh_builder, start_point, width: float3, height: float3):
   mk_poly_indexed(mb, mk_quad_geom(mb, start_point, width, height))

// Looks at convex polygon points and returns true if it has a 
// clockwise winding.  Assumes polygon has at least 3 sides.
def is_ccw_winding(pts, n):
   let calc_n = cross(pts[1].p - pts[0].p, pts[2].p - pts[0].p)

   return sign(n) == sign(calc_n)

// Given a line segment in the form of "start_point" and "extent", 
// extrudes the line in direction "dir" to make a quad.  Returns the updated
// start point.  Texture coordinates are calculated from the start_point
// using the mesh builder's world_to_tx factor, with the tc.x coord going
// in the direction of "dir".  The normal on start_point
// determines the facing of the polygon, so caller does not have to be
// concerned with the coordinate ordering of the line and dir.
def extrude_line_indexed(mb: mesh_builder, start_point, extent: float3, dir: float3):
   let dir_mags = mag_squared(dir)
   let ext_mags = mag_squared(extent)
   if dir_mags > 0.0 and ext_mags > 0.0:
      let dir_mag = sqrt(dir_mags)
      let ext_mag = sqrt(ext_mags)
      let vtxs = vector_capacity([start_point], 4)
      let p0tc = start_point.get_tc0()
      let n = start_point.get_n()
      let p1 = start_point.p + dir
      let p1tc = p0tc + float2_x*dir_mag*mb.wld_to_tx
      let p2 = start_point.p + extent + dir
      let p3 = start_point.p + extent
      push(vtxs, start_point.mknew(PNT{
         p: p1, n: n, t0: p1tc
      }))
      push(vtxs, start_point.mknew(PNT{
         p: p2, n: n, t0: p0tc + float2{dir_mag*mb.wld_to_tx, ext_mag*mb.wld_to_tx}
      }))
      push(vtxs, start_point.mknew(PNT{
         p: p3, n: n, t0: p0tc + float2_y*ext_mag*mb.wld_to_tx
      }))

      if not is_ccw_winding(vtxs, start_point.n):
         heap_swap(vtxs, 0, 3)
         heap_swap(vtxs, 1, 2)

      mk_poly_indexed(mb, vtxs)

      return start_point.mknew(PNT{
         p: p1, n: n, t0: p1tc
      })
   else:
      error(): "extrude_line_indexed: bad extent or dir {extent} {dir}"
      return start_point.mknew(PNT{
         p: start_point.p + dir, n: start_point.get_n(), 
         t0: start_point.get_tc0()
      })
      
// Lookup that associates mesh_builder instances with textures.
struct mesh_builder_lookup:
   pairs: [kvpair<resource<texture>, mesh_builder>] = []
 
   // Returns the mesh_builder associated with the given texture, returning
   // a new one if necessary.
   def lookup(key: resource<texture>) -> mesh_builder:
      let i = find_or_create(pairs, key):
         mesh_builder{}

      return pairs[i].value

   // Creates indexed meshes for all of the mesh builders, and
   // returns an aray of kvpair<resource<texture>, resource<mesh>>.
   def build_meshes_indexed(format: string) -> [kvpair<resource<texture>, resource<mesh> >]:
      let rv = []
      for(pairs) pair:
         if pair.value.has_vertices():
            push(rv, kvpair<resource<texture>,resource<mesh> >{pair.key, pair.value.make_mesh_indexed(format)})
      return rv

// Builds a mesh for a +z up capsule, where p0 is the bottom-most point.
// and p0+float3_z*height reaches the topmost point.
// n_segments controls how many faces cover the wall of the capsule.
def build_capsule_indexed(mb: mesh_builder, p0: float3, radius: float, height: float, 
                          n_segments = 15, color = color_white):
    let wall_ht = height - 2.0*radius
    let b_c = p0 + float3_z*radius
    let t_c = b_c + float3_z*wall_ht
    let n_segmentsf = float(n_segments)
    let arclen = 360.0 / n_segmentsf
 
    // Outer wall
    for(n_segments+1) i:
        let a_0 = float(i) * arclen
        let a_1 = float(i+1) * arclen
        let p_0 = float3(rotate2D(float2_x*radius, a_0), 0.0) + t_c
        let p_1 = float3(rotate2D(float2_x*radius, a_1), 0.0) + t_c
        let n_0 = normalize(float3{p_0.x, p_0.y, 0.0})
        let n_1 = normalize(float3{p_1.x, p_1.y, 0.0})
        mk_poly_indexed(mb, [
            PNC{p_0,               n_0, color},
            PNC{p_1,               n_1, color},
            PNC{p_1-float3_z*wall_ht, n_1, color},
            PNC{p_0-float3_z*wall_ht, n_0, color}])

    //TODO doing way too many elevation segments for the caps, these meshes are huge.
    // semisphere caps
    let el_step = 90.0 / n_segmentsf
    let az_step = 360.0 / n_segmentsf
    for(n_segments) elevation:
        for(n_segments) azimuth:
            // +90: to make the cap segments line up with the wall segments.
            let az = float(azimuth)*az_step + 90.0  
            let el = float(elevation)*el_step
            let x0 = sphere_coord(az,         el,         radius)
            let x1 = sphere_coord(az+az_step, el,         radius)
            let x2 = sphere_coord(az+az_step, el+el_step, radius)
            let x3 = sphere_coord(az,         el+el_step, radius)
            // top cap
            mk_poly_indexed(mb, [
                PNC{t_c + x0,     normalize(x0),   color},
                PNC{t_c + x1,     normalize(x1),   color},
                PNC{t_c + x2,     normalize(x2),   color},
                PNC{t_c + x3,     normalize(x3),   color}])

    for(n_segments) elevation:
        for(n_segments) azimuth:
            // +90: to make the cap segments line up with the wall segments.
            let az = float(azimuth)*az_step + 90.0
            let el = -float(elevation)*el_step
            let x0 = sphere_coord(az,         el,         radius)
            let x1 = sphere_coord(az+az_step, el,         radius)
            let x2 = sphere_coord(az+az_step, el+el_step, radius)
            let x3 = sphere_coord(az,         el+el_step, radius)
            // top cap
            mk_poly_indexed(mb, [
                PNC{b_c + x0,     normalize(x0),   color},
                PNC{b_c + x1,     normalize(x1),   color},
                PNC{b_c + x2,     normalize(x2),   color},
                PNC{b_c + x3,     normalize(x3),   color}])


// Returns the sphere surface coordinate for a given azimuth, elevation, radius, 
// assuming a origin of float3_0
private def sphere_coord(az: float, el: float, radius: float) -> float3:
    let a = sincos(az)
    let e = sincos(el)
    return float3{radius*e.x*a.y, radius*e.x*a.x, radius*e.y}
    
    
    
