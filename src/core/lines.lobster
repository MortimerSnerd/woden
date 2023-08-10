// Lines and related functions.
struct line_seg<T>:
   start: T
   extent: T

   def endpoint() -> T:
      return start + extent

   def mag() -> float:
      return magnitude(extent)

   // Returns the point on the segment closest to 
   // point `p`.
   def point_closest_to(p: T) -> T:
      return segment_point_closest_to(start, extent, p)


   def translated(p: T) -> line_seg<T>:
      return line_seg{start + p, extent}

   // Treats this segment as a parameteric line, returns point at given t.
   def point_at(t: float) -> T:
      return start + extent*t


struct line_seg2 = line_seg<float2>
struct line_seg3 = line_seg<float3>

// Returns the true and the t of the intersection point if the segment
// extended as an infinite line hits the plane.  Returns false if the
// segment is parallel to the plane.
def intersect_plane_seg(start: float3, extent: float3, p_normal: float3, dist: float, eps = 0.000001) -> bool, float:
   let denom = p_normal.x*extent.x + p_normal.y*extent.y + p_normal.z*extent.z
   
   if abs(denom) <= eps:
      return false, 0.0
  
   let mc = -p_normal*start
   return true, (mc.x + mc.y + mc.z + dist) / denom

def intersect_plane(self: line_seg3, p_normal: float3, dist: float, eps = 0.000001) -> bool, float:
   return intersect_plane_seg(self.start, self.extent, p_normal, dist, eps)

def intersect_plane_segment(p0: float3, extent: float3, p_normal: float3, dist: float, eps = 0.000001) -> bool, float:
   let denom = p_normal.x*extent.x + p_normal.y*extent.y + p_normal.z*extent.z
   
   if abs(denom) <= eps:
      return false, 0.0
  
   let mc = -p_normal*p0
   return true, (mc.x + mc.y + mc.z + dist) / denom

// Returns the point on the infinite line closest to the given point.
def line_point_closest_to(start, extent, point):
   let mag2 = dot(extent, extent)

   if mag2.almost_equal(0.0):
      return start
   else:
      let t0 = dot(point - start, extent) / mag2
      return start + extent*t0


def segment_point_closest_to(start: float3, extent: float3, p: float3) -> float3:
   let mag2 = dot(extent, extent)

   if mag2.almost_equal(0.0):
      return start
   else:
      // This is like projecting start -> p onto this
      // line segment, but we want the running t parameter
      // for the line first, so we can clamp it to a point on the
      // segment.
      let t0 = dot(p - start, extent) / mag2
      let tx = clamp(t0, 0.0, 1.0)
      return start + extent*tx


// intersect_plane deriv
// Ax + By + Cz - D = 0               pt on plane
// 
// A*(x0 + xe*t) + B*(y0 + ye*t) + C*(z0 + ze*t) - D  = 0
// A*x0 + A*xe*t + B*y0 + B*ye*t + C*z0 + Z*ze*t - D  = 0
// A*xe*t + B*ye*t + C*ze*t                           = -A*x0 + -B*y0 + -C*z0 + D
// A*xe + B*ye + C*ze                                 = (-A*x0 + -B*y0 + -C*z0 + D) / t
// 1 / (A*xe + B*ye + C*ze)                           = t / (-A*x0 + -B*y0 + -C*z0 + D)
// (-A*x0 + -B*y0 + -C*z0 + D) / (A*xe + B*ye + C*ze) = t

