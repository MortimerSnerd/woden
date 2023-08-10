// Some global pieces of state referenced by objects.
// And some common queries.
import core.perf
import game.grids
import game.objects


var current_level = nil :: grid_level

// Iterates objects neighboring and at the given cell coordinate. 
// Will ignore the "who" instance, which is usually the object that's
// making the query.
def for_objects_in_reach_of(who: object_instance, body):
    guard current_level
    let bb = aabb2i{who.cc-1, who.cc+1}
    current_level.for_objects_in(bb) o:
        if o != who:
            body(o)

// Iterates objects on the level of the given type.
def for_objects_of_type(ty: string, body):
    guard current_level
    for(current_level.objects) o:
        if o.type_name == ty:
            body(o)
