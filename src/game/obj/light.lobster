
import game.lights
import game.objects

class light_mixin: object_mixin
    info: lightinfo
    is_on = true

    
    def get_lightinfo(parent: object_instance) -> lightinfo?:
        if is_on:
            return info
        else:
            return nil

    def supports_interaction(parent: object_instance, who: object_instance, 
                             what: string) -> bool:
        if is_on:
            return what == ia_turn_off
        return what == ia_turn_on

    def collect_supported_interactions(parent: object_instance, who: object_instance, 
                                       acts: [string]):
        if is_on:
            push(acts, ia_turn_off)
        else:
            push(acts, ia_turn_on)

    def interact(parent: object_instance, who: object_instance, what: string) -> bool, float, string:
        guard supports_interaction(parent, who, what):
            return false, 0.0, "no can do"
        if what == ia_turn_on:
            is_on = true
        elif what == ia_turn_off:
            is_on = false
        return true, 0.1, ""

    def viz_overlaps(parent: object_instance, view: aabb2i) -> bool:
        guard is_on:
            return false
        let fr = max(1, info.radius/layer_size_factor)
        let lbb = aabb2i{parent.cc - fr, parent.cc + fr}
        return lbb.overlaps(view)

    def serialize(D: binary_editor):
        D.write_string0("light")
        D.write_byte(0)   // version 0
        D.write_int32(info.radius)
        D.write_byte(info.l0)
        D.write_byte(info.lr)
        D.write_bool(is_on)

class light_constructor: mixin_constructor
    def instantiate(desc: mixin_desc) -> string, object_mixin?:
        def missing(p):
            return "no {p} parameter for light mixin"

        def bad(p, v):
            return "bad value ({v}) for light mixin parameter {p}"

        assert desc.name == "light"
        let rad = desc.value("radius")
        guard rad:
            return missing("radius"), nil
        let radi, radok = string_to_int(rad)
        guard radok and radi > 0:
            return bad("radius", rad), nil
        

        let l0 = desc.value("l0")
        guard l0:
            return missing("l0"), nil
        let l0i, l0ok = string_to_int(l0)
        guard l0ok:
            return bad("l0", l0), nil

        let lr = desc.value("lr")
        guard lr:
            return missing("lr"), nil
        let lri, lrok = string_to_int(lr)
        guard lrok:
            return bad("lr", lr), nil

        let on = desc.value("on")
        
        return "",  light_mixin{
            info: lightinfo{
                radius: radi, 
                l0: l0i, 
                lr: lri
            },
            is_on: not on or on == "true"
        }

    def deserialize(D: binary_editor) -> string, object_mixin?:
        let ver = D.read_byte()
        guard ver == 0:
            return "bad light version {ver}", nil
    
        let r = D.read_int32()
        let l0 = D.read_byte()
        let lr = D.read_byte()
        let on = D.read_bool()
        return "", light_mixin{
            info: lightinfo{
                radius: r, 
                l0: l0, 
                lr: lr
            }, 
            is_on: on
        }

register_mixin("light", light_constructor{})
