// AI support and turn mechanism.
import core.heap
import core.logging
import game.actions

// Base class for objects that have some sort of behavior and can
// take turns.
class thinker:

    // To be overridden by subclasses.  Should return the action and action_state
    // for the action to be performed, or nil, nil if it wants to do nothing 
    // and not be called again until the next player turn.
    def next_action() -> action_desc?, action_state?:
        fatal("unimplemented next_action method")
        return nil, nil

    // Should return true if the thinker is still active.  Inactive thinkers
    // will be dropped off of the all_thinkers array, and never processed again.
    // Should be overridden.
    def still_active() -> bool:
        return true


class heapent:
    state: thinker
    t: float     // Absolute time the thinker is eligible to do another action.

// Min heap of all all thinkers, ordered by the absolute time the thinker should
// be consulted again.
private let think_heap = [] :: heapent

private def theap_order(a: heapent, b: heapent) -> bool:
    return a.t <= b.t


private def theap_add(he: heapent):
    heap_add(think_heap, he, fn(a, b): a.t <= b.t)

private def theap_pop() -> heapent:
    return heap_pop(think_heap, fn(a, b): a.t <= b.t)

// Executes the player action described by pd and ps,  runs any thinker
// actions for the time from tabs - tabs+ps.dur_s, and returns the 
// resulting absolute time. Caller can check the passed ps for the 
// execution results.
def execute_turn(pd: action_desc, ps: action_state, tabs: float) -> float:
    pd.execute(ps)
    let tnext = tabs + ps.dur_s
    assert(tnext >= tabs)

    let skips = []
    while length(think_heap) > 0 and think_heap[0].t <= tnext:
        let thk = theap_pop()
        guard thk.state.still_active()
        let t_desc, t_st = thk.state.next_action()
        if t_desc and t_st:
            t_desc.execute(t_st)
            if t_st.dur_s > 0.0:
                thk.t += t_st.dur_s
                theap_add(thk)
            else:
                error(): "execute_turn: bad action duration {t_desc} {t_st} {thk}"
                push(skips, thk)
        else:
            push(skips, thk)

    for(skips) s:
        theap_add(s)

    return tnext

def add_thinker(th: thinker, t_abs: float):
    theap_add(heapent{th, t_abs})
