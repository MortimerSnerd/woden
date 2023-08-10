// Code for allocating rectangular areas in an atlas.  Only deals with
// allocation, caller needs to do the work to get images into an atlas/texture
// using this information.
//
// First pass is simple, with very little in the way of optimization. 
import std

import core.algs
import core.rects

private struct img_area:
   dims: int2

private class column: 
   width: int
   max_height: int
   rows: [img_area]

   def used_height() -> int:
      return fold<[img_area], int>(rows, 0) acc, it: acc + it.dims.y 

   def available_height() -> int:
      return max_height - used_height()

   def add_image(dims) -> int:
      push(rows, img_area{dims})
      return length(rows) - 1

   def topmost_y_for_row(row) -> int:
      var y = 0
      for(row) r: y += rows[r].dims.y
      return y

private class page:
   dims: int2
   cols: [column]

   def add_column(width, max_h) -> int:
      push(cols, column{width, max_h, []})
      return length(cols)-1

   def used_width() -> int:
      return fold<[column], int>(cols, 0) acc, it: acc + it.width

   def available_width() -> int:
      return dims.x - used_width()

   def leftmost_x_for_col(col) -> int:
      var x = 0
      for(col) c: x += cols[c].width
      return x

   def rect_for(col, row) -> recti:
      let tl = int2{leftmost_x_for_col(col), cols[col].topmost_y_for_row(row)}
      return recti{tl, cols[col].rows[row].dims}
      

// Handle used to refer to a image added to the atlas.
struct atlas_img_handle:
   ix: int = -1

   def is_ok() -> bool:
      return ix >= 0

// unique location for an image area in a page.
private struct area_loc:
   page: int
   col: int
   row: int

class atlas_builder:
   // How large of an area to allocate smaller rects in.
   area_dims: int2
   private pages = [] :: page

   // Images we've accepted, but have not placed yet.
   private unplaced_images = [] :: kvpair<atlas_img_handle,int2>

   // Maximum width difference between an image and a column width to 
   // tolerate.  Differences larger than this we'll create a new column for.
   max_slop = 8

   private handle_acc: int = 0

   // Row column lookup indexed by handle for images that have
   // been placed.  Keeping this here
   // rather than in the handle itself, to allow images to 
   // be re-ordered without invalidating handles in an imagined
   // optimization step.
   private placed_handle_index = [] :: area_loc

   // Adds a new image if possible. Returns "error message", _ on failure, or
   // nil, handle on success.   Does not immediately place an image, it's better
   // to add a batch of images, and then call "place()" to place the images.
   def add(dims: int2) -> string?, atlas_img_handle:
      if dims.x <= 0 or dims.y <= 0:
         return "atlas_builder.add: invalid image dimensions {dims}", atlas_img_handle{}
      elif dims.x > area_dims.x or dims.y > area_dims.y:
         return "atlas_builder.add: image dims ({dims}) too big for atlas {area_dims}", atlas_img_handle{}
      else:
         let hnd = atlas_img_handle{ix: handle_acc}
         handle_acc += 1
         push(unplaced_images, kvpair<atlas_img_handle,int2>{hnd, dims})
         return nil, hnd

   // Places any unplaced images.  
   def place_images():
      if length(unplaced_images) > 1:
         // Descending width, start with the bigger images.
         qsort_in_place(unplaced_images) a, b: a.value.x > b.value.x

      for(unplaced_images) p:
         place(p.key, p.value)
      unplaced_images = []

   // Returns the page a handle has been placed at, or -1 if it has
   // not been placed.
   def page_for(h: atlas_img_handle) -> int:
      if h.is_ok():
         return placed_handle_index[h.ix].page
      else:
         return -1

   // Returns the page number and destination rect for the given handle.
   // Only valid to call after place_images() has been called since the call
   // to add that produced the handle.
   def rect_for(h: atlas_img_handle) -> int, recti:
      assert(h.is_ok())
      let loc = placed_handle_index[h.ix]
      assert(loc.page >= 0)
      return loc.page, pages[loc.page].rect_for(loc.col, loc.row)

   // After place_images() has been called, returns the number of 
   // atlas pages needed to hold all of the images.
   def num_pages() -> int:
      return length(pages)

   // Places an individual image.
   private def place(handle, img_dims):
      var least_error = INT_MAX
      var least_pg = -1
      var least_col = -1
      var row = -1

      for(pages) pg, pg_no:
         for(pg.cols) col, col_no:
            let err = col.width - img_dims.x
            if err >= 0 and err < least_error and err < max_slop and col.available_height() >= img_dims.y:
               least_error = err
               least_pg = pg_no
               least_col = col_no

      if least_pg < 0:
         // No existing fit, add new column to existing page?
         for(pages) pg, pg_no:
            if pg.available_width() >= img_dims.x:
               least_col = pg.add_column(img_dims.x, area_dims.y)
               least_pg = pg_no
               break

      if least_pg < 0:
         // Add new page.  The column has to fit, unless the width
         // invariants in add have been "worked around"
         assert(img_dims.x <= area_dims.x)
         least_pg = length(pages)
         push(pages, page{area_dims, []})
         least_col = pages[least_pg].add_column(img_dims.x, area_dims.y)

      assert(least_pg >= 0)
      row = pages[least_pg].cols[least_col].add_image(img_dims)
      eassign(placed_handle_index, handle.ix, area_loc{least_pg, least_col, row},
              area_loc{-1, -1, -1})


// Creates an atlas builder managing an atlas image of the given size, 
// with no pre-defined column widths. 
def mk_atlas_builder(area_dims: int2) -> atlas_builder:
   return atlas_builder{area_dims: area_dims, pages: [page{area_dims, []}]}
