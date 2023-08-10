// Classes for storing data in cartesian grids of cells, 
// where the cell is a user supplied type.

// Classic array representation of a grid that's presumably 
// dense
class dense_grid<T>:
   // Width, height of grid.
   dims: xy_i   

   // Default element that the array is filled with on creation.
   default_elem: T

   // number of entries per grid.
   n_ents: int = 1

   // Array that contains cells.
   cells: [T] = []

   // Resets the backing array back to its initial state.
   def reset():
      let ncells = dims.x*dims.y*n_ents
      cells = vector_capacity([], ncells)
      for(ncells):
         push(cells, default_elem)

   // returns the index into "cells" for the given coordinates.
   // Does not check against bounds.
   def IX(x: int, y: int) -> int:
      return x*n_ents + y*dims.x*n_ents

   // Returns true if x, y is in bounds of the grid.
   def in_bounds(x, y) -> bool:
      return x >= 0 and x < dims.x and y >= 0 and y < dims.y   

   // Returns the given element number of the cell at (x, y).
   // If the coordinates are out of bounds, the value of oob(x, y)
   // is returned.
   def get_orelse(x: int, y: int, elem_no: int, oob) -> T:
      if this.in_bounds(x,y):
         return cells[this.IX(x, y) + elem_no]
      else:
         return oob(x, y)
      
   def get_orelse(p: xy_i, elem_no: int, oob) -> T:
      return get_orelse(p.x, p.y, elem_no, oob)
   
   // Returns the given element number of the cell at (x, y).
   // If the coordinates are out of bounds, the default_elem is returned.
   def get(x: int, y: int, elem_no: int) -> T:
      return this.get_orelse(x, y, elem_no): default_elem

   def get(p: xy_i, elem_no: int) -> T:
      return this.get(p.x, p.y, elem_no)

   // Stores the value at the given coordinates, if they are in bounds.
   def put(x: int, y: int, v: T, elem_no: int):
      if this.in_bounds(x, y):
         cells[this.IX(x, y) + elem_no] = v

   def put(p: xy_i, v: T, elem_no: int):
      return this.put(p.x, p.y, v, elem_no)

   // Iterates all coords in the grid, in row major order.
   def for_all_coords(body):
      for(dims.y) y:
         for(dims.x) x:
            body(x, y)


def mk_dense_grid<T>(dims: xy_i, default_elem: T, n_ents: int) -> dense_grid<T>:
   assert(dims.x > 0)
   assert(dims.y > 0)
   assert(n_ents > 0)
   let rv = dense_grid<T>{dims: dims, default_elem: default_elem, n_ents: n_ents}
   rv.reset()
   return rv

//NB sometimes I have problems with template functions like mk_dense_grid acting like
// code is only generated for the first T it sees, and using different types causes
// it to have odd type errors.  So explictly instantiating a float version here.
def mk_dense_float_grid(dims: xy_i, defelem: float, n_ents: int) -> dense_grid<float>:
   assert(dims.x > 0)
   assert(dims.y > 0)
   assert(n_ents > 0)
   let rv = dense_grid<float>{dims: dims, default_elem: defelem, n_ents: n_ents}
   rv.reset()
   return rv

