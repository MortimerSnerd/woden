import core.aabb

// Visibility determination via munificent's 
// algorithm:  http://journal.stuffwithstuff.com/2015/09/07/what-the-hero-sees/
//

// `start` and `end` are slopes.
private class Shadow:
   start: float  
   end: float

private class ShadowLine:
   shadows: [Shadow]

private def project_tile(row: int, col: int):
   let fr = float(row)
   let fc = float(col)
   let tl = fc / (fr + 2.0)
   let br = (fc + 1.0) / (fr + 1.0)

   return Shadow{start: tl, end: br}

private def contains_shadow(s:: Shadow, other: Shadow):
   return start <= other.start and end >= other.end

private def is_in_shadow(sl:: ShadowLine, projection: Shadow):
   return exists(shadows) s: s.contains_shadow(projection)

private def add(sl:: ShadowLine, new_shadow: Shadow):
   var idx = 0
   while idx < length(shadows):
      if shadows[idx].start >= new_shadow.start: break
      ++idx

   var ovr_prev: Shadow? = nil
   if idx > 0 and shadows[idx-1].end > new_shadow.start:
      ovr_prev = shadows[idx - 1]

   var ovr_next: Shadow? = nil
   if idx < length(shadows) and shadows[idx].start < new_shadow.end:
      ovr_next = shadows[idx]

   if ovr_next:
      if ovr_prev:
         ovr_prev.end = ovr_next.end
         remove(shadows, idx)
      else:
         ovr_next.start = new_shadow.start
   else:
      if ovr_prev:
         ovr_prev.end = new_shadow.end
      else:
         insert(shadows, idx, new_shadow)

private def is_full_shadow(sl:: ShadowLine):
   return length(shadows) == 1 and shadows[0].start <= 0.0 and shadows[0].end >= 1.0

private def refresh_octant(start_pos: int2, octant: int, bounds: aabb2i, block_test, body):
   let line = ShadowLine{shadows: []}
   var row = 1

   while true:
      var pos = start_pos + transform_octant(octant, row, 0)
      if not bounds.contains(pos): break

      var col = 0
      while col <= row:
         pos = start_pos + transform_octant(octant, row, col)
         if not bounds.contains(pos): break

         let proj = project_tile(row, col)
         let visible = not line.is_in_shadow(proj)
         if visible: 
            let opaque = block_test(pos)
            body(pos, opaque)
            if opaque:
               line.add(proj)
               if line.is_full_shadow(): return
         ++col
      ++row

// Calls body(pos, opaquebool) for all visible tiles from `start_pos`
// block_test should be a functon that takes a grid position and
// returns true if light is blocked at that position.
def walk_visible_tiles(start_pos: int2, bounds: aabb2i, block_test, body):
   for(8) octant:
      refresh_octant(start_pos, octant, bounds, block_test, body)

// start offsets for variant of walk_visibile_tiles that avoids overlapping
// tests
private let nooverlap_octant_offsets = [
    int2_1,
    int2_1,
    int2_x,
    int2_x,
    int2_0,
    int2_0,
    int2_y,
    int2_y
]

// Like walk_visible_tiles, but has unique start points for each quadrant. 
// Takes the start_pos as the top left of a 1x1 block of points, and performs
// visibility checks using the cell from the 1x1 block appropriate for the quadrant
// the pass is in. 
//
// Originally created for a case where there are 4x4 visibility cells for each
// floor cell, so there wasn't a way to cast from the exact center of the floor
// cell, causing shadows skewed to one side or the other.
def walk_visible_tiles_quad(start_pos: int2, bounds: aabb2i, block_test, body):
   for(8) octant:
      refresh_octant(start_pos + nooverlap_octant_offsets[octant], octant, bounds, block_test, body)

