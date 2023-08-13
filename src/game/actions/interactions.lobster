// Actions for some standard object interactions.
import core.logging
import game.actions
import game.defs
import game.objects

// Class that supports a single interaction type.
class object_interaction: target_action
    interaction_name: string    // Interaction name as defined by object mixins.

    def validate(who: object_instance, target: object_instance, st: action_state) -> bool:
        //TODO there's no inventory yet, so only interact with objects out in the level
        guard who.cc.is_neighbor_of(target.cc):
            st.rc = rc_out_of_range
            return false

        guard target.supports_interaction(who, interaction_name):
            st.rc = rc_invalid
            return false

        st.rc = rc_ok
        st.dur_s = 0.3          //TODO
        st.msg = ""
        st.kb_action = kb_action
        st.who = who
        st.what = target
        return true
    
    def execute(st: action_state):
        guard st.rc == rc_ok and st.what:
            error(): "object_interaction: bad state {st}"

        let suc, dur, err = st.what.interact(st.who, interaction_name)
        if suc:
            st.dur_s = dur
        else:
            st.rc = rc_interaction_failed
            st.msg = err
        

register_action(object_interaction{
    name: "open", 
    short_desc: "open a door or container",
    kb_action: kb_open, 
    interaction_name: "open"
})
register_action(object_interaction{
    name: "close", 
    short_desc: "close a door or container",
    kb_action: kb_close, 
    interaction_name: "close"
})
register_action(object_interaction{
    name: "turn on", 
    short_desc: "turn item on",
    kb_action: kb_turn_on,
    interaction_name: ia_turn_on
})
register_action(object_interaction{
    name: "turn off", 
    short_desc: "turn item off",
    kb_action: kb_turn_off,
    interaction_name: ia_turn_off
})

