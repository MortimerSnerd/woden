// Code for checking possible moves.
import game.actions
import game.objects

// Iterates through possible moves, calling body(action_desc, action_state) for
// each one.  TRAP: the action_state record gets reused on each iteration, 
// so if the caller wants to save it, they need to do a copy() on it.
def for_possible_actions(who: object_instance, body):
    let st = action_state{who: who, what: nil, where: int2_0}
    for(action_reg) a_desc:
        switch a_desc:
            case self_action:
                //TODO
                pass()

            case target_action:
                if a_desc.only_neighbors:
                    for_objects_in_reach_of(who) target:
                        if a_desc.validate(who, target, st):
                            body(a_desc, st)
                else:
                    //TODO visible targets for ranged, etc?
                    pass()

            case location_action:
                if a_desc.only_neighbors:
                    for_neighboring_positions(who.cc) cc:
                        if a_desc.validate(who, cc, st):
                            body(a_desc, st)
            
