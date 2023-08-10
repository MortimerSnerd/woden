// Axis aligned bounding boxes.
import vec

// Axis aligned bounding box for a given point type.
// mins and maxs bounds are inclusive.
struct aabb<T>:
    mins: T
    maxs: T

    def contains(p: T) -> bool:
        return all_true(p >= mins) and all_true(p <= maxs)

    def overlaps(o: aabb<T>) -> bool:
        guard not o.is_degenerate() and not is_degenerate():
            return false
        if not all_false(maxs < o.mins):
            return false
        if not all_false(mins > o.maxs):
            return false
        return true

    def union(o: aabb<T>) -> aabb<T>:
        guard not is_degenerate():
            return o
        guard not o.is_degenerate():
            return this
        return aabb<T>{min(mins, o.mins), max(maxs, o.maxs)}

    def width():
        return maxs.x - mins.x + 1

    def height():
        return maxs.y - mins.y + 1

    def for_x(body):
        for(width()) xo:
            body(mins.x + xo)

    def for_y(body):
        for(height()) yo:
            body(mins.y + yo)

    def for_allxy(body):
        for(height()) yo:
            for(width()) xo:
                body(int2{mins.x+xo, mins.y+yo})


    def is_degenerate() -> bool:
        return some_false(maxs >= mins)

struct aabb3f = aabb<float3>
struct aabb2f = aabb<float2>
struct aabb2i = aabb<int2>
struct aabb3i = aabb<int3>

// Helpers for aabb methods.
def all_true(a: int2) -> bool:
    return a.x != 0 and a.y != 0

def all_true(a: int3) -> bool:
    return a.x != 0 and a.y != 0 and a.z != 0

def all_true(a: int4) -> bool:
    return a.x != 0 and a.y != 0 and a.z != 0 and a.w != 0

def all_false(a: int2) -> bool:
    return a.x == 0 and a.y == 0

def all_false(a: int3) -> bool:
    return a.x == 0 and a.y == 0 and a.z == 0

def all_false(a: int4) -> bool:
    return a.x == 0 and a.y == 0 and a.z == 0 and a.w == 0

def some_false(a) -> bool:
    return not all_true(a)

def extent(a: aabb2i) -> int2:
    return a.maxs - a.mins + int2_1

def area(a: aabb2i) -> int:
    let e = extent(a)
    return e.x*e.y
