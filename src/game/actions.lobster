// Some minimal abstraction around actions that can be 
// taken in a turn, to allow for querying for possible
// actions, either by the player ui, or by ai.  It would
// be nice to avoid allocating a bunch of crap just to test
// whether a move would be valid.
import game.defs
import game.objects


enum act_result_codes:
    rc_ok, 
    rc_out_of_range,
    rc_does_nothing,
    rc_movement_blocked,
    rc_invalid

// Result class for actions tests and executions, that allow the action_desc
// to return specific reasons for failure, action duration, user presentable
// messages.  Also stores any action parameters required by execute()
class action_state:
    rc: act_result_codes = rc_invalid
    dur_s = 0.0
    msg = ""
    kb_action = ""   // action name for a key binding that invokes this.
    who: object_instance
    what: object_instance?
    where: int2

    def clear():
        rc = rc_invalid
        what = nil
        msg = ""
    
// Description object of a action, that can describe what parameters it needs, 
// test to see if an action is possible, report what key binding action can 
// invoke the action.  Subclasses implement the validate 
// methods, as the subclasses will need different parameters.
// It's important for execute to directly follow the validate call before
// any global game state gets changed that could invalidate the action.
// Don't validate and then sit on it before doing anything with it.
class action_desc:
    name: string
    short_desc: string
    kb_action: string

    def execute(st: action_state):
        fatal("action_desc: unimplemented execute() method")

// action parameter types that we have action_desc subclasses for.
// objself              - just needs instigator
// objself, objtarget   - action on another object
// objself, cc  - action targeted at a position.

// Action on self.
class self_action: action_desc
    // Returns true if the given action is valid.  (doesn't necessarily
    // mean it will succeed in game terms, just that it's possible to try)
    // If res is supplied, it will be populated.
    def validate(who: object_instance, res: action_state) -> bool:
        fatal("self_action: not implemented")
        return false


// Action on a target object.
class target_action: action_desc
    def validate(who: object_instance, target: object_instance, res: action_state) -> bool:
        fatal("action_desc: other case not implemented")
        return false

// Action with a given target location on the level.
class location_action: action_desc
    // If true, only neighbors are considered valid locations
    only_neighbors = true

    def validate(who: object_instance, target_cc: int2, res: action_state) -> bool:
        fatal("action_desc: other case not implemented")
        return true

// Registry of all known actions.
let action_reg = [] :: action_desc

// Called by other module to register actions.  Fancy, avoids import cycles 
// Action names should be unique.
def register_action(a: action_desc):
    let ex = find(action_reg): _.name == a.name
    guard ex < 0:
        fatal("Duplicate action name for {a}")
    push(action_reg, a)

//TODO code for querying possible actions for an object goes here?
