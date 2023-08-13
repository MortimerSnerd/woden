// Static and dynamic objects that can be placed in levels.
import core.aabb
import core.kvpair

import data.binary

import game.blocks
import game.defs
import game.draw
import game.lights

// Block index and render flags, describes a image. 
struct obj_image:
    block: int
    flags: int     // df_flags from game.draw

    def is_valid():
        return block >= 0

    def serialize(D: binary_editor):
        D.write_int32(block)
        D.write_int64(flags)

def deserialize_obj_image(D: binary_editor) -> obj_image:
    let b = D.read_int32()
    let f = D.read_int64()
    return obj_image{b, f}

let NO_IMAGE = obj_image{-1, 0}

// Slots for classifying images associated with an object
enum image_slots:
    slot_default,
    slot_default1,         // Used sometimes for items with two states
    slot_damaged,
    slot_verydamaged,
    slot_dead,
    slot_open, 
    slot_closed

def named_image(s: image_slots, block: int, flags = 0) -> kvpair<image_slots, obj_image>:
    assert is_valid_block(block)
    return kvpair<image_slots, obj_image>{s, obj_image{block, flags}}

def named_image(s: image_slots, img: string, flags = 0):
    return named_image(s, block_index_for(img), flags)

enum_flags object_flags:
    of_static              // does not move
    of_blocks_move         // Blocks movement.
    of_blocks_light

// Parsed mixin description, with parameters
class mixin_desc:
    name: string
    pnames = [] :: string
    pvals = [] :: string

    def value(nm: string) -> string?:
        let i = find(pnames): _ == nm
        if i >= 0:
            return pvals[i]
        else:
            return nil

    def add(nm: string, val: string) -> mixin_desc:
        push(pnames, nm)
        push(pvals, val)
        return this

// Object types - information that is shared between instances.
struct object_type:
    name: string        // Unique name for the object type.
    flags: int          // of_*

    // Images, tagged by image_slots
    images: [kvpair<image_slots, obj_image>]

    // Mixin descriptions.  These are used at object instance creation time if
    // no override mixin_desc is provided.
    mixins: [mixin_desc]

// Object types are referenced by index, to make serializing objects simpler.
private let object_types = [] :: object_type


// Mixins that provide functional building blocks + state for object instances. 
class object_instance
class object_mixin:
    // Called when the mixin is added to the object, at creation time, 
    // or right after being loaded.
    def on_load(parent: object_instance, creation: bool):
        pass()

    // Returns true, flgval if the mixin overrides one of the
    // static object_type flags. Returns false, ? otherwise.
    def overrides_flag(parent: object_instance, flg: int) -> bool, bool:
        return false, false

    // Returns an overridden current image slot, or slot_default if there's
    // no override
    // no current override.
    def cur_img_slot(parent: object_instance) -> image_slots:
        return slot_default

    // Allows override of the image for a given slot.
    def img_for_slot(parent: object_instance, slot: image_slots) -> obj_image:
        return NO_IMAGE

    def supports_interaction(parent: object_instance, who: object_instance, 
                             what: string) -> bool:
        return false

    def interact(parent: object_instance, who: object_instance, what: string) -> bool, float, string:
        return false, 0.0, "no can do"

    // Returns true if this mixin causes the object to overlap the view rect.
    // Anything that overlaps the view rect will be rendered.
    def viz_overlaps(parent: object_instance, view: aabb2i) -> bool:
        return false

    // Appends any supported interactions to the given list.
    def collect_supported_interactions(parent: object_instance, who: object_instance, 
                                       acts: [string]):
        pass()

    // Override to serialize the mixin.  First item written must be the name
    // the mixin was registerd as, null terminated.
    def serialize(D: binary_editor):
        pass()

    def get_lightinfo(parent: object_instance) -> lightinfo?:
        return nil

// Constuctor for mixins.  Used to associate a mixin name with a constructor.
class mixin_constructor:
    // Subclass override to create a mixin with the given parameters.
    def instantiate(param: mixin_desc) -> string, object_mixin?:
        return "error: instantiate not overriden for mixin", nil

    // Given a binary editor, deserializes this type of mixin.  The initial 
    // mixin name has already been read off the stream, so only the remaining
    // mixin specific paramameters need to be read.
    def deserialize(D: binary_editor) -> string, object_mixin?:
        return "error: deserialize not overriden for mixin", nil



// Private registry for mixin constructors. 
private let mixin_reg_names = [] :: string
private let mixin_reg_fns = [] :: mixin_constructor

// TODO this is just a skeleton right now
private def deserialize_mixin(D: binary_editor) -> string, object_mixin?:
    let mname = D.read_string0()
    let mi = find(mixin_reg_names): _ == mname
    guard mi >= 0:
        return "deserialize_mixin: error, unknown mixin {mname}", nil
    
    return mixin_reg_fns[mi].deserialize(D)

// Called to register constructors for mixins.  So we don't need to 
// pile them all in this module with a hardcoded function for mixin creation.
def register_mixin(name: string, fun: mixin_constructor):
    assert length(mixin_reg_names) == length(mixin_reg_fns)
    guard (find(mixin_reg_names): _ == name) < 0
    push(mixin_reg_names, name)
    push(mixin_reg_fns, fun)

// Selects parameters for a mixin, giving priority to the passed mxparams list 
// over the object_type mixin parameters.
private def mixin_parameters_for(otype: int, mixin_name: string, mxparams: [mixin_desc]) -> string, mixin_desc?:
    let i = find(mxparams): _.name == mixin_name
    if i >= 0:
        return "", mxparams[i]

    let i1 = find(object_types[otype].mixins): _.name == mixin_name
    if i1 >= 0:
        return "", object_types[otype].mixins[i1]

    return "no parameters found for {mixin_name} mixin", nil

// Lookup mixin constructor in registry and invoke it
private def instantiate_mixin(otype: int, mixin_name: string, mxparams = [] :: mixin_desc) -> string, object_mixin?:
    let ri = find(mixin_reg_names): _ == mixin_name
    guard ri >= 0:
        return "unknown mixin name: {mixin_name}", nil

    let err, param = mixin_parameters_for(otype, mixin_name, mxparams)
    guard param:
        return err, nil
    return mixin_reg_fns[ri].instantiate(param)

// Base class for objects.  Just a position and a type.
// Contains methods to be possibly overridden.
class object_instance:
    typei: int      // index into object_types
    cc: int2        // Floor cell coordinate.
    mixins = [] :: object_mixin
    opaque_mask = 0 // Light blocking mask. 16 bits for the 4x4 grid of wall 
                    // coordinates enclosed by a floor cell location. 

    //TODO what state do we need where to indicate a object is not on the level, 
    //     but in a container, etc   Objectid ints, and a field for container?
    //     Do not want pointer graphs.  Levels will keep up with the objects they
    //     contain.

    // Returns the type name of this object instance.
    def type_name() -> string:
        return object_types[typei].name

    // Name that can be presented to a user.
    def p_name() -> string:
        return type_name()

    // Calls body(flgvalue: bool) if any mixin overrides
    // the given flag.  First mixin that overrides wins.
    private def with_mixin_overridden_flag(flg: int, body):
        for(mixins) m:
            let ov, val = m.overrides_flag(this, flg)
            if ov:
                body(val)
                return

    // Returns the lightinfo for this object if it's a light emitter.
    // Nil otherwise.
    def get_lightinfo() -> lightinfo?:
        for(mixins) m:
            let li = m.get_lightinfo(this)
            if li:
                return li
        return nil

    // Returns true if this object's area of effect overlaps the view
    // area.  view is in floor cell coordinates.
    def viz_overlaps(view: aabb2i) -> bool:
        if view.contains(cc):
            return true

        for(mixins) m:
            if m.viz_overlaps(this, view):
                return true

        return false

    // Given a wall coordinate assumed to be in our floor coordinate, 
    // returns true if the opaque mask marks that coordinate as opaque.
    def blocks_light(wc: int2) -> bool:
        if opaque_mask == 0:
            return false

        let rc = wc - floor_to_wall(cc) 
        let bm = 1 << (rc.x + rc.y*4)
        return (bm&opaque_mask) != 0

    def blocks_move() -> bool:
        with_mixin_overridden_flag(of_blocks_move) v: return v
        return object_types[typei].flags.has(of_blocks_move)

    // Returns the current image slot that should be used for 
    // rendering.  
    def cur_img_slot() -> image_slots:
        for(mixins) m:
            let s = m.cur_img_slot(this)
            if s != slot_default:
                return s
        return slot_default

    // Can override for objects that have complicated state.
    def cur_image() -> obj_image:
        let s = cur_img_slot()
        for(mixins) m:
            let img = m.img_for_slot(this, s)
            if img.is_valid():
                return img

        let i = find(object_types[typei].images): _.key == slot_default or _.key == slot_default1
        if i >= 0:
            return object_types[typei].images[i].value
        else:
            return object_types[typei].images[0].value

    def supports_interaction(who: object_instance, what: string) -> bool:
        for(mixins) m:
            if m.supports_interaction(this, who, what):
                return true
        return false

    // Returns true, duration, message if the interaction works
    // Returns false, duration, message if the interaction does not work.
    def interact(who: object_instance, what: string) -> bool, float, string:
        var firstmsg = ""
        for(mixins) m:
            if m.supports_interaction(this, who, what):
                let suc, dur, msg = m.interact(this, who, what)
                if suc:
                    return suc, dur, msg
                if firstmsg == "":
                    firstmsg = msg

        if firstmsg == "":
            firstmsg = "can\'t do that"

        return false, 0.0, firstmsg
        
    // Populates "acts" with the names of supported interactions for "who".
    def collect_supported_interactions(who: object_instance, acts: [string]):
        for(mixins) m:
            m.collect_supported_interactions(this, who, acts)

    def draw():
        let img = cur_image()
        draw_image(img.block, cc*floor_pxsize, dyn_obj_render_layer, img.flags)

    // Returns true if the object is on the floor in a level.
    def is_on_floor() -> bool:
        //TODO
        return true

    def serialize(D: binary_editor):
        D.write_string("obi0")   // version 0
        D.write_int32(typei)
        D.write_vertex2i(cc)
        D.write_array(mixins) m:
            m.serialize(D)
            
    def deserialize(D: binary_editor) -> string?:
        let tag = D.read_string(4)
        guard tag == "obi0":
            return "deserialize object instance: bad tag {tag}"
        typei = D.read_int32()
        cc = D.read_vertex2i()
        mixins = D.read_array(): 
            let err, mx = deserialize_mixin(D)
            guard mx:
                return err
            mx
        for(mixins) mx:
            mx.on_load(this, false)
        return nil

// Creates a new object of the given type, at the given cell position.  If
// no parameters are given for the mixins, the object type defaults are used.
def create_object(otype: int, cc: int2, mxparams = [] :: mixin_desc) -> string, object_instance?:
    guard otype >= 0 and otype < length(object_types):
        return "create_object: bad otype {otype}", nil

    let rv = object_instance{
        typei: otype, 
        cc: cc
    }
    for(object_types[otype].mixins) mxp:
        let err, mx = instantiate_mixin(otype, mxp.name, mxparams)
        if not mx:
            return "create_object: {err}", nil
        mx.on_load(rv, true)
        push(rv.mixins, mx)

    return "", rv

// Creates a new object of the given type, at the given cell position.  If
// no parameters are given for the mixins, the object type defaults are used.
def create_object(otype: string, cc: int2, mxparams = [] :: mixin_desc) -> string, object_instance?:
    return create_object(find(object_types): _.name == otype, cc, mxparams)
    
// Should be called sometime after blocks is initialized.
def init_objects() -> string?:
    //TODO this will read in a desc file at some point.  
    push(object_types, object_type{
        name: "door", 
        flags: 0, 
        images: [],
        mixins: [
            mixin_desc{
                name: "door", 
                pnames: ["open", "closed", "orient"],
                pvals: [ "dev/door1vo.png", "dev/door1vc.png", "v"]
            }
        ]
    })
    push(object_types, object_type{
        name: "player", 
        flags: 0, 
        images: [named_image(slot_default, "dev/pc.png", 0)],
        mixins: []
    })

    push(object_types, object_type{
        name: "lantern", 
        flags: 0, 
        images: [named_image(slot_default, "dev/lantern.png", 0)],
        mixins: [
            mixin_desc{
                name: "light", 
                pnames: ["radius", "l0", "lr"],
                pvals: ["16", "50", "10"]}
        ]
    })

    return nil
    
