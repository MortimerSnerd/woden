// Structures and supporting functions for lights.
import core.aabb
import core.algs
import game.propmap

class lightinfo:
    radius: int    // In wall coordinates, not floor cell coordinates 
    l0: int        // Light level at light position, 0-255
    lr: int        // Light level at radius distance from center.

    // Returns the world wall coordinate bounding box with the given light 
    // wall coordinate position.
    def world_aabb(pos_wc: int2) -> aabb2i:
        return aabb2i{pos_wc - radius, pos_wc + radius}
   

    // Returns the light value for the given wall coordinates.
    // Returns 0 if the point is out of range.
    def light_contribution(pos_wc: int2, wc: int2) -> int:
        let r2 = radius*radius
        let pr2 = mag_squared(wc - pos_wc)

        if pr2 > r2:
            return 0
        return floor(lerp(float(l0), float(lr), float(pr2)/float(r2)))
        
