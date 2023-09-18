import vec

// Overhead camera.  xy is the ground plane, +z up.
// By default, is oriented so +x is to the right, and -y is down
class OverheadCam:
   pos: xyz_f
   d_angle: float = 0.0   // Difference from looking straight down.

   def setup_view():
      gl.rotate_y(sincos(d_angle))   // Look down.
      gl.rotate_x(sincos(d_angle))   // Look down.
      gl.translate(-pos)
