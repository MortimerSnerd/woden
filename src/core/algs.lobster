import gl
import std
import vec
      
let INT_MAX = 0x7fffffffffffffff


// s begins with 'prefix'?
def begins_with(s: string, prefix: string) -> bool:
   return find_string(s, prefix) == 0

// We define our own rather than build off cardinal_directions and 
// diagonal_directions, so they can be in clockwise order rather
// than interleaved.

// Indexes into all_dirs
enum Directions:
   East, SouthEast, South, SouthWest, West, NorthWest, North, NorthEast

// Vectors for all grid directions, in the order of the `Directions` enum.
let all_dirs = [int2{1, 0}, int2{1, 1}, int2{0, 1}, int2{-1, 1}, int2{-1, 0}, 
                int2{-1, -1}, int2{0, -1}, int2{1, -1}]

let all_dirs_f = [float2{1.0, 0.0}, float2{1.0, 1.0}, float2{0.0, 1.0}, float2{-1.0, 1.0}, float2{-1.0, 0.0}, 
                  float2{-1.0, -1.0}, float2{0.0, -1.0}, float2{1.0, -1.0}]

let opposite_dir = [West, NorthWest, North, NorthEast, East, SouthEast, 
                    South, SouthWest]

// Angle in degrees for all directions in all_dirs.
let dir_angles = map(all_dirs) d: normalize_angle(atan2(float2{float(d.x), float(d.y)}))

// For an array of numbers, returns the index of the entry
// closest to x.  Returns -1 for an empty array.
def closest_to(arr, x):
   var closest = -1

   for(arr) n, i:
      if closest < 0 or abs(x - n) < abs(x - arr[closest]):
         closest = i

   return closest

// If i ranges from 0..num-1, returns
// the previous i, cycling around to the 
// end of the range when i == 0
def cycle_left(i: int, num: int) -> int:
   if i <= 0:
      return num - 1
   else:
      return i - 1

def turned_left(d: Directions) -> Directions:
   return Directions(cycle_left(d, length(all_dirs)))

def turned_right(d: Directions) -> Directions:
   return Directions(cycle_right(d, length(all_dirs)))

def for_neighboring_positions(pos: int2, body): 
   for(all_dirs) d:
      body(d + pos)

def is_neighbor_of(a: int2, b: int2) -> bool:
   let diff = a - b
   return (find(all_dirs): _ == diff) >= 0

// Returns -num steps (if b is to the left of a) or
// +num steps if b is to the right of a.  Returns 0
// if they are the same,
def dir_diff(a: Directions, b: Directions) -> int:
   if a == b:
      return 0
   else:
      var c = 0
      var lrab = a
      var rrab = a

      while c == 0 or (lrab != b and rrab != b):
         ++c
         lrab = lrab.turned_left()
         rrab = rrab.turned_right()

      if rrab == b:
         return c
      elif lrab == b:
         return -c
      else:
         return 0

// Returns closest direction that would face `a` towards `b`.
def approx_dir(a: int2, b: int2) -> Directions:
   let af = float2{a.x, a.y}
   let bf = float2{b.x, b.y}
   let dd = normalize(bf - af)

   def roundn(r):
      if r >= 0.5:
         return 1
      elif r <= -0.5:
         return -1
      else:
         return 0

   let di = int2{roundn(dd.x), roundn(dd.y)}
   let idx = find(all_dirs) x: x == di

   assert idx >= 0
   return Directions(idx)

// Returns the point that is a single integral step
// from a in the direction of b.
def step_towards(a: int2, b: int2) -> int2:
   let d = approx_dir(a, b)

   return a + all_dirs[d]

def turned_right_90deg(v):
   return vec2{-v.y, v.x} 

def turned_left_90deg(v: int2) -> int2:
   return int2{v.y, -v.x}

def turned_left_90deg(v: float2) -> float2:
   return float2{v.y, -v.x}

def is_diagonal(v: int2) -> bool:
   return v.x != 0 and v.y != 0

// If i ranges from 0..num-1, returns
// the next i, cycling around to the 
// end of the range when i == num-1
def cycle_right(i: int, num: int) -> int:
   if i >= num-1:
      return 0
   else:
      return i + 1

// To the power of 2.
def squared(a):
   return a * a

// Rotate v aronund the origin, where scang = sincos(ang)
def rotate_around_origin(v: float2, scang: float2) -> float2:
   return float2{v.x*scang.x - v.y*scang.y, v.x*scang.y + v.y*scang.x}

// Is a close to b for a given epsilon?
def almost_equal(a: float, b: float, eps: float = 0.00001):
    return abs(a - b) <= eps

// To treat small arrays as sets, adds an item only if it isn't already in the array.
def set_push(arr, v):
   if (find(arr): _ == v) == -1:
      push(arr, v)

// Treating arrays as binary heaps.
private def lchild(i: int) -> int:
   return 2*i + 1

private def rchild(i: int) -> int:
   return 2*i + 2

private def parent(i:int) -> int:
   assert i != 0
   return (i-1)/2 // Assume: division floored.

def heap_swap<T>(arr: [T], ai: int, bi: int):
   let t = arr[ai]
   arr[ai] = arr[bi]
   arr[bi] = t

def heap_bubble_up<T>(arr: [T], i: int, cmpfn):
   var pos = i

   while pos > 0 and not cmpfn(arr[parent(pos)], arr[pos]):
      heap_swap(arr, parent(pos), pos)
      pos = parent(pos)

def heap_bubble_down<T>(arr: [T], i: int, cmpfn):
   var pos = i
   var inplace = false

   while not inplace and pos < length(arr)-1:
      let li = lchild(pos)
      let ri = li + 1
      let li_exists = li < length(arr)
      let ri_exists = ri < length(arr)

      if (not li_exists or cmpfn(arr[pos], arr[li])) and (not ri_exists or cmpfn(arr[pos], arr[ri])):
         inplace = true
      else:
         if li_exists and ri_exists:
            if cmpfn(arr[li], arr[ri]):
               heap_swap(arr, pos, li)
               pos = li
            else:
               heap_swap(arr, pos, ri)
               pos = ri
         else:
            // One child is not present.
            if li_exists:
               heap_swap(arr, pos, li)
               pos = li
            else:
               heap_swap(arr, pos, ri)
               pos = ri

// Treats `arr` like a binary heap, and adds
// item to the proper place in the tree.  
// cmpfn can be <= for a min heap, or >= for a max
// heap.  
def heap_add<T>(arr: [T], item: T, cmpfn):
   let i = length(arr)
   push(arr, item)
   heap_bubble_up(arr, i, cmpfn)

def heap_pop<T>(arr: [T], cmpfn) -> T:
   let rv = arr[0]

   if length(arr) == 0:
      pop(arr)
   else:
      arr[0] = arr[length(arr)-1]
      pop(arr)
      heap_bubble_down(arr, 0, cmpfn)

   return rv

// Searches for entry in `xs` where cmpfn(xs[x], key) == 0. 
// `cmpfn(a, b)` should return < 0 if keyof(a) < key.
// Returns (true, index) of found item, or (false, index where the item would be)
// if it is not found.  The returned index is the least bounds index for the
// key.
def binary_search_by_key(xs, key, cmpfn) -> bool, int:
   var rv = 0
   var found = false

                        
   if length(xs) > 0:
      var lo = 0
      var hi = length(xs) -1

      while hi >= lo:
        if lo == hi:
          rv = lo
          if cmpfn(xs[lo], key) == 0:
             found = true
          break
        else:
           rv = lo + (1+hi-lo)/2
           let eq = cmpfn(xs[rv], key)

           if eq == 0:
              found = true
              break
           elif eq < 0:
             lo = rv + 1
           else:
             hi = rv - 1

   // See if there are any duplicates before us
   while rv > 0 and cmpfn(xs[rv-1], key) == 0:
      --rv

   // Special case for key > max(xs)
   if rv == length(xs) - 1 and  cmpfn(xs[rv], key) < 0:
      ++rv

   return found, rv

// Centers the text horizontally, placing it
// at y*win_height.  If y <= 0, assumed to be a negated y coordinate instead
// of a multiplier.  Assumes the default ortho projection.
def center_text_x(txt: string, y: float = 0.5):
   let wsz = to_f(gl_window_size())
   let tdim = gl_text_size(txt)
   let acty = if y < 0.0: -1.0 * y else: y*wsz.y

   gl_translate(float2{wsz.x*0.5 - tdim.x*0.5, acty}):
      gl_text(txt)

// Represents a linear interpolation happening in a distinct
// time interval.
class LERP<T>:
   startT: float
   endT: float
   start: T
   end: T

def scale_time(l, f: float):
   l.startT *= f
   l.endT *= f

def mkLERP<T>(startTime: float, endTime: float, start: T, end: T) -> LERP<T>:
   assert endTime > startTime
   return LERP<T>{startT: startTime, endT: endTime, start: start, end: end}

def mkConstLERP<T>(v: T) -> LERP<T>:
   return mkLERP(0.0, 0.1, v, v)

def eval<T>(l::LERP<T>, t: float):
   let f = clamp((t - startT) / (endT - startT), 0.0, 1.0)

   return lerp(start, end, f)

// Specialized LERP for angles.
class AngleLERP:
   startT: float
   endT: float
   start: float
   end: float

def normalize_angle(f: float) -> float:
   var rv = f

   while rv < 0.0:
      rv += 360.0

   while rv > 360.0:
      rv -= 360.0

   return rv % 360.0

// Makes a LERP between angles, following the shortest path.
// (ie, 10 to 350 only goes 20 degrees.)
def mkAngleLERP(startTime: float, endTime: float, start: float, end: float) -> AngleLERP:
   assert endTime > startTime

   let sa = normalize_angle(start)
   let ea = normalize_angle(end)
   let plen = abs(ea - sa)
   let nlen = min(ea, sa) + 360 - max(ea, sa)

   if plen < nlen:
      return AngleLERP{startT: startTime, endT: endTime, start: sa, end: ea}
   else:
      if ea < sa:
         return AngleLERP{startT: startTime, endT: endTime, start: sa, end: ea + 360}
      else:
         return AngleLERP{startT: startTime, endT: endTime, start: sa + 360, end: ea}


def eval(l::AngleLERP, t: float):
   let f = clamp((t - startT) / (endT - startT), 0.0, 1.0)

   return normalize_angle(lerp(start, end, f))

def mkConstAngleLERP<T>(v: T) -> AngleLERP:

   return mkAngleLERP(0.0, 0.1, v, v)

// Calculates a position of a point on an arc from a0 to a1 given a percentage.
// TODO: for the moment it's up to the caller to be aware of discontinuities in 
//       angle ranges if they are being derived from atan2.
//  r = radius, f = percentage
def arc(a0: float, a1: float, r: float, f: float) -> float2:
   let a = lerp(a0, a1, clamp(f, 0.0, 1.0))

   return sincos(a) * r

def noop():
   return

struct Interval:
   lo: float
   hi: float

   def is_empty() -> bool:
      return hi <= lo
   
   def intersection(other) -> Interval:
      return Interval{max(lo, other.lo), min(hi, other.hi)}

   def intersects(other) -> bool:
      return not intersection(other).is_empty()

struct LineSegment:
   start: float2
   extent: float2

   def endpoint() -> float2:
      return start + extent

   def mag() -> float:
      return magnitude(extent)

   // Returns the point on the segment closest to 
   // point `p`.
   def point_closest_to(p: float2) -> float2:
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

   def x_interval() -> Interval:
      let ex = start.x + extent.x
      return Interval{min(start.x, ex), max(start.x, ex)}

   def translated(p: float2) -> LineSegment:
      return LineSegment{start + p, extent}

def line(a: float2, b: float2) -> LineSegment:
   return LineSegment{a, b-a}

// Rectangle with inclusive bounds. +y is considered down
// as a convention.
struct Rect:
   topLeft: int2
   bottomRight: int2

   // Returns a rectangle whose size is contracted by `size`.
   // Does not prevent degenerate rectangles.
   def contracted(size: int) -> Rect:
      return Rect{topLeft + int2{size, size}, bottomRight - int2{size, size}}

   // Returns a rectangle whose size is expanded by `size`.
   def expanded(size: int) -> Rect:
      return contracted(-size)

   // Splits the rect vertically at `x`, and 
   // returns left half.
   def hsplit_left(x: int) -> Rect:
      return Rect{topLeft, int2{x-1, bottomRight.y}}
   
   // Splits the rect vertically at `x`, and 
   // returns right half.  The right half will start at x.
   def hsplit_right(x: int) -> Rect:
      return Rect{int2{x, topLeft.y}, bottomRight}
   
   // Splits the rect horizontally at 'y' and returns the top half.
   def vsplit_top(y: int) -> Rect:
      return Rect{topLeft, int2{bottomRight.x, y-1}}

   // Splits the rect horizontally at 'y' and returns the bottom half, 
   // which starts at `y`.
   def vsplit_bottom(y: int) -> Rect:
      return Rect{int2{topLeft.x, y}, bottomRight}

   // Returns center point of the Rect.
   def center() -> int2:
      let d = bottomRight - topLeft + int2{1,1}
      return topLeft + d/2

   def render_outline(thickness: float):
      let p0 = to_f(topLeft)
      let p1 = to_f(int2{bottomRight.x, topLeft.y})
      let p2 = to_f(bottomRight)
      let p3 = to_f(int2{topLeft.x, bottomRight.y})
      gl_line(p0, p1, thickness)
      gl_line(p1, p2, thickness)
      gl_line(p2, p3, thickness)
      gl_line(p3, p0, thickness)

   def width() -> int:
       return bottomRight.x - topLeft.x + 1

   def height() -> int:
       return bottomRight.y - topLeft.y + 1

def bottomRightf(r: Rect):
   return float2{float(r.bottomRight.x), float(r.bottomRight.y)}

def rect_for_circle(c: int2, r: int) -> Rect:
   assert r >= 0
   let hr = int2{r, r}
   return Rect{c - hr, c + hr}

struct Rectf:
   topLeft: float2
   bottomRight: float2

   // Returns a rectangle whose size is contracted by `size`.
   // Does not prevent degenerate rectangles.
   def contracted(size: float) -> Rectf:
      return Rectf{topLeft + float2{size, size}, bottomRight - float2{size, size}}

   // Returns a rectangle whose size is expanded by `size`.
   def expanded(size: float) -> Rectf:
      return contracted(-size)

def is_degenerate(r) -> bool:
   return r.bottomRight.x < r.topLeft.x or r.bottomRight.y < r.topLeft.y

let degenerate_rect = Rect{int2{1, 1}, int2{0, 0}}

// If rects a & b overlap on the x axis, will
// return loval, hival where hival > loval.  
// hival <= loval means no intersection.
def x_intersection(a, b) -> float, float:
   let lo = max(a.topLeft.x, b.topLeft.x)
   let hi = min(a.bottomRight.x, b.bottomRight.x)

   return lo, hi

// Returns true if rects a & b overlap along the x axis.
def x_overlaps(a, b):
   let lo, hi = x_intersection(a, b)

   return hi > lo

// If rects a & b overlap on the y axis, will
// return loval, hival where hival > loval.  
// hival <= loval means no intersection.
def y_intersection(a, b) -> float, float:
   let lo = max(a.topLeft.y, b.topLeft.y)
   let hi = min(a.bottomRight.y, b.bottomRight.y)

   return lo, hi

// Returns true if rects a & b overlap along the y axis.
def y_overlaps(a, b):
   let lo, hi = y_intersection(a, b)

   return hi > lo

// Returns true if the two rects overlap.
def overlaps(a, b) -> bool:
   return x_overlaps(a, b) and y_overlaps(a, b)

def contains(r::Rect, pos: int2) -> bool:
   return (pos.x >= r.topLeft.x and pos.x <= r.bottomRight.x and
      pos.y >= r.topLeft.y and pos.y <= r.bottomRight.y)

def dims(r::Rect) -> int2:
   return int2{1 + bottomRight.x - topLeft.x, 1 + bottomRight.y - topLeft.y}

def area(r::Rect) -> int:
   let d = r.dims
   return d.x * d.y

def isDegenerate(r::Rect) -> bool:
   return r.area <= 0

def mkRectRel(topLeft: int2, dims: int2) -> Rect:
   return Rect{topLeft, int2{topLeft.x + dims.x - 1, topLeft.y + dims.y - 1}}


def contains(r::Rectf, pos: float2) -> bool:
   return (pos.x >= r.topLeft.x and pos.x <= r.bottomRight.x and
      pos.y >= r.topLeft.y and pos.y <= r.bottomRight.y)

def dims(r::Rectf) -> float2:
   // This is so cheesy. Technically, there shouldn't be a constant epsilon, but
   // something based on the next representable value given the values of x, y.
   // But probably not important enough to lose sleep over.  Picking a small value
   // that probably won't cause noticable issues. 
   let eps = 2.220446049250313080847e-16
   return float2{eps + bottomRight.x - topLeft.x, eps + bottomRight.y - topLeft.y}

def area(r::Rectf) -> float:
   let d = r.dims
   return d.x * d.y

def isDegenerate(r::Rectf) -> bool:
   return r.area <= 0

def mkRectfRel(topLeft: float2, dims: float2) -> Rectf:
   let eps = 2.220446049250313080847e-16
   return Rectf{topLeft, float2{topLeft.x + dims.x - eps, topLeft.y + dims.y - eps}}

def gridToWorld(p:: int2) -> float2:
   return float2{x: float(x) + 0.5, y: float(y) + 0.5}

// Magnitude of a -> b vec.
def gridDistance(a: int2, b: int2) -> float:
   return magnitude(float2{a.x, a.y} - float2{b.x, b.y})

def worldToGrid(p:: float2) -> int2:
   return int2{x: int(x - 0.5), y: int(y - 0.5)}

def gridRect(p: float2) -> Rectf:
   let gc = worldToGrid(p)
   return mkRectfRel(float2{float(gc.x), float(gc.y)}, float2_1)

def gridRect(p: int2) -> Rectf:
   let gc = worldToGrid(float2{p.x, p.y})
   return mkRectfRel(float2{float(gc.x), float(gc.y)}, float2_1)

// Converts a world rect to a grid rect.
def worldToGrid(r: Rectf) -> Rect:
   return Rect{worldToGrid(r.topLeft), worldToGrid(r.bottomRight)}

// Reads the current mouse position, and converts it to 
// world coordinates, based on the passed in view rectangle.
// `tile_size` is the size map tiles are displayed in, in pixels.
def world_mouse_pos(view: Rectf, tile_size: float) -> float2:
   let mpi = gl_mouse_pos(0)
   let wsz = gl_window_size()
   let viewsz = view.bottomRight - view.topLeft

   if wsz.x > 0 and wsz.y > 0:
      let xf = float(mpi.x) / float(wsz.x)
      let yf = float(mpi.y) / float(wsz.y)

      return float2{view.topLeft.x + xf*viewsz.x, 
                  view.topLeft.y + yf*viewsz.y}
   else:
      return float2_0


def render(r:: Rectf, thickness):
   gl_line(topLeft, float2{bottomRight.x, topLeft.y}, thickness)
   gl_line(float2{bottomRight.x, topLeft.y}, bottomRight, thickness)
   gl_line(bottomRight, float2{topLeft.x, bottomRight.y}, thickness)
   gl_line(float2{topLeft.x, bottomRight.y}, topLeft, thickness)

// Calls body only with the items in `arr` that match `pred`.
def filter_call(arr, pred, body):
   for(arr) x:
      if pred(x):
         body(x)

// Removes an item by swapping in the last item, rather
// than shifting the array.  If the array was ordered before, 
// it probably isn't now.
def unordered_remove(xs, i):
   let lasti = length(xs) - 1

   if i == lasti:
      pop(xs)
   else:
      xs[i] = xs[lasti]
      pop(xs)

// Like rnd_float() but returns number in range of -1..1
def rnd_float_org() -> float:
   return 1.0 - 2.0*rnd_float()

private def rndcheck():
   for(400):
      let nums = []
      for(1000):
         push(nums, rnd(500))

      let sorted = copy(nums)

      qsort_in_place(sorted) a, b: a < b

      for(nums) x:
         let found, i = binary_search_by_key(sorted, x) a, b: a - b

         if not found:
            print(sorted)
            print("could not find " + x + ", should go to " + i)
            break

def ends_with(what: string, suffix: string) -> bool:
   let suflen = length(suffix)

   if length(what) >= suflen:
      let sfx = substring(what, length(what) - suflen, suflen)
      return sfx == suffix
   else:
      return false

// Tests whether any flags in `test` are set in `flags`.
def has_any(flags: int, test: int) -> bool:
   return flags & test != 0

// Tests whether all of the flags in `test` are set in `flags`.
def has(flags: int, test: int) -> bool:
   return flags & test == test

// Returns true if none of the flags in test
// are set in `flags`.
def denies(flags: int, test: int) -> bool:
   return flags & test == 0

// is x within [a,b]  (inclusive on both ends).
// a should be <= b
def within(x, a, b) -> bool:
   return x >= a and x <= b

def heapcheck():
   let hcmp = fn(a: int, b: int) -> bool:
      a <= b

   for(400):
      let hp = []
      for(1000): heap_add(hp, rnd(500), hcmp)
      let check = copy(hp)
      assert length(hp) == 1000
      qsort_in_place(check) a, b: a < b
      let hsorted = []
      while length(hp) > 0:
         push(hsorted, heap_pop(hp, hcmp))

      if not equal(hsorted, check):
         print("HSORTED " + hsorted)
         print("CHECK   " + check)
         assert false

def qsort_in_place(keys, vals, lt):
    def rec(s, e) -> void:
        let l = e - s
        if l > 1:
            let pivot = keys[s]
            let pivotval = vals[s]
            var sp = s + 1
            var ep = e
            while sp < ep:
                let c = keys[sp]
                if lt(c, pivot):
                    keys[sp - 1] = keys[sp]
                    vals[sp - 1] = vals[sp]
                    sp++
                else:
                    let v = vals[sp]
                    keys[sp] = keys[--ep]
                    vals[sp] = vals[ep]
                    keys[ep] = c
                    vals[ep] = v
            
            keys[--sp] = pivot
            vals[sp] = pivotval
            rec(s, sp)
            rec(ep, e)

    rec(0, keys.length)

// The absolute start and end times of a player turn.
// Animations are scaled and possibly moved within this
// duration so at the end of the turn, objects animation positions
// matches up with the actual positions of the objects on the grid.
// Without this, you can get into hard to read situations, where a 
// object moves towards the end of the turn, so visually it appears
// that they're still in the starting grid, but effectively they're already
// on grid location over.
struct TurnSpan:
   start: float
   end: float

// Used for player actions.  The span gets adjusted to the real action
// time onece the action is presented.
let FakeTurnSpan = TurnSpan{0.0, 999999999990.0}

// Assigns arr[idx] = val.  If length(arr) < idx, 
// the array is extended with defval entries until it
// is the correct size.
def eassign(arr, idx, val, defval):
   while length(arr) <= idx:
      push(arr, defval)

   arr[idx] = val

def mag_squared(p: int2) -> int:
    return p.x*p.x + p.y*p.y

def mag_squared(p):
   return dot(p, p)

def mag(t:: TurnSpan) -> float:
   assert t.end >= t.start
   return end - start

// Embedded links class to inherit from.
class EmbeddedDLinks<T>:
   dl_next: T? = nil
   dl_prev: T? = nil

// Reference to a circular doubly linked list.
class EmbeddedCircList<T>:
   head: T?
   count: int = 0

// Adds an item to the list.  Not valid if the
// item is already in a list.
def dl_add<T>(list: EmbeddedCircList<T>, item: T):
   assert item.dl_next == nil
   assert item.dl_prev == nil

   if list.head:
      item.dl_next = list.head
      item.dl_prev = list.head.dl_prev
      if item.dl_prev:
         item.dl_prev.dl_next = item
      item.dl_next.dl_prev = item
   else:
      item.dl_next = item
      item.dl_prev = item
      list.head = item

   ++list.count

// Removes an item from a doubly linked circular list.
def dl_remove<T>(list: EmbeddedCircList<T>, item: T):
   if item.dl_prev:
      item.dl_prev.dl_next = item.dl_next
   if item.dl_next:
      item.dl_next.dl_prev = item.dl_prev

   if list.head and list.head == item:
      if item.dl_next == item:
         // last item in circular list.
         list.head = nil
      else:
         list.head = item.dl_next

   item.dl_next = nil
   item.dl_prev = nil
   --list.count

// Removes all entries.  If this isn't done
// before you're done with a list, you'll get
// a memory leak report because of the cycles.
def dl_clear<T>(list: EmbeddedCircList<T>):
   let fst = list.head

   if fst:
      var cur:T? = fst
      repeat():
         let nxt = cur.dl_next
         cur.dl_next = nil
         cur.dl_prev = nil
         cur = nxt
      fn():
         cur != fst

      list.head = nil

// Loop across two arrays.
def for2(a0, a1, body):
   for(a0) a: body(a)
   for(a1) b: body(b)

// Loop backwards over an array, passing both the
// value and the index for each item from end to beginning.
def for_reverse(a, body):
   let lasti = length(a) - 1
   for(length(a)) i:
      let ri = lasti - i
      body(a[ri], ri)

// If the list isn't empty, calls body with the index of the last
// item.
def with_last_index(a, body):
    let l = length(a)
    if l > 0:
        body(l-1)

// Search for index where pred(x) == true, and return it,
// or return -1 if not found.
def find_reverse(a, pred):
   for_reverse(a) v, i:
      if pred(v):
         return i
   return -1

// repeat() until type of loop.
//     repeat():
//       print('hi')
//       --x
//     fn():
//       x > 0
// Probably not useful, just verifying I can do it
// and seeing how it works out.
def repeat(body, whilecond):
   body()

   while whilecond():
      body()

// Loop n times when you don't need the index.
def loop(n, body):
   var i = 0
   while i < n:
      body()
      i++

def dl_foreach<T>(list: EmbeddedCircList<T>, body):
   if list.head:
      var o: T? = list.head

      repeat():
         if o:  // Should always be true, but we must check.
            body(o)
            o = o.dl_next
      fn():
         o != list.head

def dl_find<T>(list: EmbeddedCircList<T>, predfn) -> T?:
   dl_foreach(list) i:
      if predfn(i):
         return i

   return nil

// Multipliers for row, col for the different octants.
def transform_octant(octant: int, row: int, col: int) -> int2:
   switch octant:
      case 0: return int2{col, -row}
      case 1: return int2{row, -col}
      case 2: return int2{row, col}
      case 3: return int2{col, row}
      case 4: return int2{-col, row}
      case 5: return int2{-row, col}
      case 6: return int2{-row, -col}
      case 7: return int2{-col, -row}
   assert false



def to_f(p: int2):
   return float2{float(p.x), float(p.y)}

def to_i(p: float2):
   return int2{int(p.x), int(p.y)}

// Given a initial velocity upwards and gravity, returns the max
// height a projectile will acheive if is fired directly upward.
def max_projectile_height(vy0: float, g: float) -> float:
   return (vy0*vy0)/(2*g)

// Refactoring of max_projectile_height to solve for the upward velocity
// needed to get a specific max height.
def v_for_max_projectile_height(height: float, g: float) -> float:
   return sqrt(2.0*height*g)

// Time in flight a projectile takes with a starting upward velocity
// of vy0 and gravity of g.
def projectile_time_of_flight(vy0: float, g: float) -> float:
   return (2.0 * vy0) / g


// Return a letter choice for a list of choices.  Practically limited to a
// 26 + 10 digits, since we can't do uppercase.  We return "" the limits
// are exceeded.
def choice_letter(i: int):
   var rv = " "

   if i >= 0 and i < 25:
      rv.write_int8_le(0, i + 97)
   elif i >= 26 and i < 36:
      rv.write_int8_le(0, i - 26 + 48)
   else:
      rv = ""

   return rv

// Visits all grid positions between start and finish, in that order.
def iter_line(start: int2, finish: int2, body):
   // We use floats, because using floats is not that expensive, and it's
   // a pain to reconcile Bresenham's algorithm to always go from start to 
   // finish. Translation of DDA from http://www.cse.yorku.ca/~amana/research/grid.pdf
   let tdy = finish.y - start.y
   let tdx = finish.x - start.x
   var x = start.x
   var y = start.y

   if tdy == 0:
      let dx = sign(tdx)
      while x != finish.x:
         body(int2{x, y})
         x += dx
      body(finish)
   elif tdx == 0:
      let dy = sign(tdy)
      while y != finish.y:
         body(int2{x, y})
         y += dy
      body(finish)
   else:
      let v = normalize(to_f(finish) - to_f(start))
      var t_max_x = 1.0 / v.x
      var t_max_y = 1.0 / v.y
      let t_delta_x = t_max_x
      let t_delta_y = t_max_y
      var fx = float(start.x) 
      var fy = float(start.y)

      while true:
         let cp = int2{floor(fx+0.5), floor(fy+0.5)}
         body(cp)
         if cp == finish:
            return
         if abs(t_max_x) < abs(t_max_y):
            t_max_x += t_delta_x
            fx += sign(t_delta_x)
         else:
            t_max_y += t_delta_y
            fy += sign(t_delta_y)

// Given a line segment of grid coordinates, returns the endpoint that 
// would extend the segment's length to `len`.
def extend_grid_line(start: int2, end: int2, len: int) -> int2:
    assert start != end
    assert len > 0
    let p0 = to_f(start) + float2{0.5, 0.5}
    let p1 = to_f(end) + float2{0.5, 0.5}
    let v = (p1 - p0).normalize()
    let pn = p0 + v * float(len) 

    return floor(pn)

def algs_tests():
   rndcheck()

   var found = false
   var ix = 0

   found, ix = binary_search_by_key([10, 20], 10) a, b: a - b
   assert found
   assert ix == 0

   found, ix = binary_search_by_key([11, 20], 20) a, b: a - b
   assert found
   assert ix == 1

   found, ix = binary_search_by_key([11, 20], 0) a, b: a - b
   assert not found
   assert ix == 0

   found, ix = binary_search_by_key([11, 20], 21) a, b: a - b
   assert not found
   assert ix == 2

   let ss = mkLERP(1.0, 2.0, 0.0, 100.0)

   assert eval(ss, 0) == 0
   assert eval(ss, 3) == 100
   assert eval(ss, 1) == 0
   assert eval(ss, 2) == 100
   assert eval(ss, 1.5) == 50

   let r1 = Rectf{float2{1.5, 3.5}, float2{2.5, 4.5}}
   let r2 = Rectf{float2{-10.0, -10.0}, float2{10.0, 10.0}}

   assert r1.overlaps(r2)
   assert r2.overlaps(r1)

   heapcheck()
