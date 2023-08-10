// Axis aligned rectagles.

private def mkfloat(pt):
   if pt.x is float:
      return pt
   else:
      return float2{float(pt.x), float(pt.y)}

// Generic 2D rect.  Expected that only P can be either int2 or float2.
struct rect<P>:
   top_left: P
   extent: P

   // Private helper functions that allow us to instantiate the right
   // types without being able to use P as a type constructor.
   private def mkpt(a, b):
      if a is float:
         return float2{a, b}
      else:
         return int2{a, b}

   private def halve(x):
      if x is float:
         return x*0.5
      else:
         return x / 2

   // Returns area of rect.
   def area():
      return extent.x * extent.y

   // Returns the bottom-most rightmost point that's contained
   // within the rectangle.
   def bottom_right():
      if top_left.x is float:
         // This is so cheesy. Technically, there shouldn't be a constant epsilon, but
         // something based on the next representable value given the values of x, y.
         // But probably not important enough to lose sleep over.  Picking a small value
         // that probably won't cause noticable issues. 
         let eps = 2.220446049250313080847e-16
         return top_left + extent - float2{eps,eps}
      else:
         return top_left + extent - int2{1,1}

   // Returns a rectangle whose size is contracted by `size`.
   // Does not prevent degenerate rectangles.
   def contracted(size) -> rect<P>:
      let dp = mkpt(halve(size), halve(size))
      return rect<P>{top_left + dp, extent - dp}

   // Returns a rectangle whose size is expanded by `size`.
   def expanded(size: int) -> rect<P>:
      return contracted(-size)

   private def x_must_be_in_range(x):
      assert x >= top_left.x and x < (top_left.x + extent.x)

   private def y_must_be_in_range(y):
      assert y >= top_left.y and y < (top_left.y + extent.y)

   // Returns the left portion of the rect, where anything x >= top_left.x
   // and < x is contained in the left portion.  Invalid if x is out of the
   // range of the rect.
   def split_left(x) -> rect<P>:
      x_must_be_in_range(x)
      return rect<P>{top_left, mkpt(x-top_left.x, extent.y)}
   
   // Returns the right portion of the rect, where anything >= x
   // and < (x + extent.x) is contained in the left portion.  Invalid if x is out of the
   // range of the rect.
   def split_right(x) -> rect<P>:
      x_must_be_in_range(x)
      return rect<P>{mkpt(x, top_left.y), mkpt(extent.x - (x - top_left.x), extent.y)}
   
   // Returns the top portion of this rectangle, where anything >= top_left.y and
   // < y will be in the top portion.  Invalid if y is out of range of the rect.
   def split_top(y) -> rect<P>:
      y_must_be_in_range(y)
      return rect<P>{top_left, mkpt(extent.x, y-top_left.y)}

   // Returns the bottom portion of this rectangle, where anything >= y and
   // < (y + extent.y) will be in the top portion.  Invalid if y is out of range of the rect.
   def split_bottom(y) -> rect<P>:
      y_must_be_in_range(y)
      return rect<P>{mkpt(top_left.x, y), mkpt(extent.x, extent.y - (y - top_left.y))}

   // Returns center point of the Rect.
   def center():
      return top_left + mkpt(halve(extent.x), halve(extent.y))

   // Renders an outline.  The outline covers points that are contained in the
   // rectangle.
   def render_outline(thickness: float):
      let br = bottom_right()
      let p0 = top_left.mkfloat
      let p1 = mkpt(br.x, top_left.y).mkfloat
      let p2 = br.mkfloat
      let p3 = mkpt(top_left.x, br.y).mkfloat
      gl_line(p0, p1, thickness)
      gl_line(p1, p2, thickness)
      gl_line(p2, p3, thickness)
      gl_line(p3, p0, thickness)

   // Returns true if p is a point inside of the rectangle.
   def contains(p) -> bool:
      let bound = top_left + extent
      return p.x >= top_left.x and p.y >= top_left.y and p.x < bound.x and p.y < bound.y

   // Returns true if this is a degenerate rect with no area.
   def is_degenerate() -> bool:
      return extent.x <= 0 and extent.y <= 0


// Synonym for integer rect
struct recti = rect<int2>
// Synonym for float rect
struct rectf = rect<float2>

def as_rectf(r: recti) -> rectf:
   return rectf{float(r.top_left), float(r.extent)}

// Returns the union of this and another rect.
def union(a: recti, b: recti) -> recti:
    if a.is_degenerate(): 
        return b
    if b.is_degenerate():
        return a

    let br = a.bottom_right()
    let obr = b.bottom_right()
    let mins = min(a.top_left, b.top_left())
    let maxs = max(br, obr)
    return recti{mins, maxs-mins}

