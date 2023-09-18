import game.objects

class mixin_door: object_mixin
    open: bool = false
    open_img = NO_IMAGE
    closed_img = NO_IMAGE
    horizontal = false      // Orientation of door on screen.

    private def update_opaque_mask(parent):
        // Make sure the parent opaque mask is correct for our
        // current state.
        if open:
            parent.opaque_mask = 0x0
        else:
            if horizontal:
                parent.opaque_mask = 0x0ff0
            else:
                parent.opaque_mask = 0x6666

    def on_load(parent: object_instance, creation: bool):
        update_opaque_mask(parent)

    def overrides_flag(parent: object_instance, flg: int) -> bool, bool:
        if flg.has(of_blocks_move):
            return true, not open
        if flg.has(of_blocks_light):
            return true, not open
        return false, false

    def img_for_slot(parent: object_instance, slot: image_slots) -> obj_image:
        return if open: open_img else: closed_img
    
    def supports_interaction(parent: object_instance, who: object_instance, 
                             what: string) -> bool:
        if open:
            return what == "close"
        else:
            return what == "open"

    def interact(parent: object_instance, who: object_instance, what: string) -> bool, float, string:
        guard supports_interaction(parent, who, what):
            return false, 0.0, "can not be {what}ed"
        //TODO check to make sure nothing that blocks the door is in the way for close
        open = what == "open"
        update_opaque_mask(parent)
        return true, 0.2, ""

    def collect_supported_interactions(parent: object_instance, who: object_instance, 
                                       acts: [string]):
        if open:
            push(acts, "close")
        else:
            push(acts, "open")

    def serialize(D: binary_editor):
        D.write_string0("door")
        D.write_byte(0)   // version 0
        D.write_bool(open)
        open_img.serialize(D)
        closed_img.serialize(D)

class door_constructor: mixin_constructor
    def instantiate(desc: mixin_desc) -> string, object_mixin?:
        assert desc.name == "door"
        let oname = desc.value("open")
        guard oname:
            return "no open parameter for door mixin", nil
        let cname = desc.value("closed")
        guard cname:
            return "no closed parameter for door mixin", nil

        var horiz = false
        let orient = desc.value("orient")
        if orient:
            if orient == "h":
                horiz = true
            elif orient == "v":
                horiz = false
            else:
                return "door: bad value for orient: {orient} should be h | v", nil 

        return "", mixin_door{
            open: false, 
            open_img: obj_image{block_index_for(oname), 0},
            closed_img: obj_image{block_index_for(cname), 0},
            horizontal: horiz
        }

    def deserialize(D: binary_editor) -> string, object_mixin?:
        let v = D.read_byte()
        guard v == 0:
            return "bad door mixin version {v}", nil
        
        let rv = mixin_door{}
        rv.open = D.read_bool()
        rv.open_img = deserialize_obj_image(D)
        rv.closed_img = deserialize_obj_image(D)
        return "", rv

register_mixin("door", door_constructor{})
