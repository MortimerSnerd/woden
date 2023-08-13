import game.actions
import game.defs
import game.state

let dir_to_action = [kb_east, kb_southeast, kb_south, kb_southwest, kb_west, 
                     kb_northwest, kb_north, kb_northeast]

class move_action: location_action
    def validate(who: object_instance, target_cc: int2, st: action_state) -> bool:
        guard current_level:
            st.rc = rc_invalid
            return false

        let md = target_cc - who.cc 
        if md == int2_0 or abs(md.x) > 1 or abs(md.y) > 1:
            st.rc = if md == int2_0: rc_does_nothing else: rc_out_of_range
            return false

        guard current_level.can_move_by(who, md):
            st.rc = rc_movement_blocked
            return false

        let i = find(all_dirs): _ == md
        assert i >= 0
        st.rc = rc_ok
        st.msg = ""
        st.dur_s = 1.0  //TODO calc move speeds
        st.who = who
        st.where = target_cc
        st.kb_action = dir_to_action[i]

        return true

    def execute(st: action_state):
        guard current_level
        assert current_level.move_by(st.who, st.where - st.who.cc) 
        
register_action(move_action{name: "move", short_desc: "move one step", 
                            kb_action: ""})
