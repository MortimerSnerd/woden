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
            case action_desc:
                // ?
                pass()

            case location_action:
                if a_desc.only_neighbors:
                    for_neighboring_positions(who.cc) cc:
                        if a_desc.validate(who, cc, st):
                            body(a_desc, st)
