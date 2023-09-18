// Camera with yaw and pitch.  Changes the default GL view of
// -z forward, +y up to -y forward, -z up.
//
// This is mainly to get the x/y plane coordinates to line up nicely
// with how 2d grids are addressed. The camera module that ships with lobster 
// had the x and y axis mirrored, which was error prone when moving between
// grid addressing and generating geometry from the grid.
//
// Some pieces of this copied from the camera module, since it mainly just
// changes the view setup.
import vec

class camera:
   position: xyz_f
   yaw: float = 0.0
   pitch: float = 0.0

   // Performs the camera transform.
   def FPS_view():
      // Rotates the view for fwd -y, up -z. 
      gl.rotate_x(sincos(90.0))

      gl.rotate_x(sincos(-pitch))
      gl.rotate_z(sincos(-yaw))
      gl.translate(-position)

   //TODO - this view vector from camera is based on wrong coordinate system
   //       so worldobj and this code need to be fixed at the same time.
   def forward_vector(): 
      return vecfromyawpitch(yaw, pitch,        1.0, 0.0)

   def yaw_vector() -> xyz_f:
      return xyz(rotate_around_origin(-xy_y, sincos(yaw)), 0.0)
