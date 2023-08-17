// Simple base object for a game mode.  Hang your state off a subclass,
// and reimplement the methods.
import std
import core.algs

enum input_result:
    ir_ok, 
    ir_finished // returned when the game mode is finished.

class game_mode:
    def update(d_t: float) -> input_result:
        return ir_ok

    def render():
        pass()

    // If it returns true, render_active_mode() will render the
    // previously active mode before rendering this mode.
    def render_previous_mode() -> bool:
        return false

    // Called when it becomes active.  "reactivation" is true if it is
    // being re-activated after another mode has deactivated.
    def on_activate(reactivation: bool):
        pass()

    // Called when it becomes inactive.  If removed==true, it means
    // the mode is being popped off the mode stack, and not coming back.
    def on_deactivate(removed: bool):
        pass()

private let mode_stack = [] :: game_mode

// Activates the mode.
def activate_mode(m: game_mode):
    with_last_index(mode_stack) i:
        mode_stack[i].on_deactivate(false)
    push(mode_stack, m)
    m.on_activate(false)

// Deactivates the last activated mode.
def deactivate_mode():
    if length(mode_stack) > 0:
        let m = pop(mode_stack)
        m.on_deactivate(true)
        with_last_index(mode_stack) i:
            mode_stack[i].on_activate(true)
        
// Updates the current mode.
def update_active_mode(d_t: float):
    with_last_index(mode_stack) i:
        switch mode_stack[i].update(d_t):
            case ir_ok:
                pass()
            case ir_finished:
                deactivate_mode()        

// Renders the current mode
def render_active_mode():
    with_last_index(mode_stack) last:
        var i = last
        while i > 0 and mode_stack[i].render_previous_mode():
            i--
        for_range_incl(i, last) j:
            mode_stack[j].render()

def has_active_mode() -> bool:
    return length(mode_stack) > 0


