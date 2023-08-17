// Support for text prompts for the player
import color
import texture

import core.bindings
import game.defs
import game.mode

class prompt_choice<P>:
    key: key_desc
    payload: P

// The base prompt.  Can process input, and render itself. 
// update() returns ir_finished when there's an answer, with result==nil for
// a cancel, or set to the chosen prompt_choice.
//
// This was going to be a game_mode, but ran into the "class blah already
// used in dynamic dispatch" issue, without a clear way to re-order the
// code to avoid it.
class player_prompt<P>:
    result: prompt_choice<P>?
    choices: [prompt_choice<P>]
    cancel_key = key_desc{0, "escape"}

    def update(d_t: float) -> input_result:
        for(choices) c:
            if c.key.test(key_went_down) > 0:
                result = c
                return ir_finished

        if cancel_key.test(key_went_down) > 0:
            result = nil
            return ir_finished

        return ir_ok


    def render():
        pass()
    
// direction prompt - created with valid direction choices, but 
// only briefly asks for a direction.
class direction_prompt<P>: player_prompt<P>
    prompt: string

    def render():
        set_prompt_font()
        let dims = gl_text_size(prompt)
        let margin = max(2, dims.y/4)
        let wsz = float(gl_window_size())
        gl_ortho()
        gl_set_shader("color")
        gl_blend(blend_alpha)
        gl_color(prompt_bg)
        gl_rect(float2{wsz.x, dims.y+margin})
        gl_color(prompt_fg)
        gl_translate(float2_1 * float(margin)):
            gl_text(prompt)

// Creates a direction prompt.  We're not checking to see if
// the given choices are actually directions.
constructor direction_prompt<P>(c: [prompt_choice<P>]):
    assert length(c) > 0
    var prompt = "Direction? "
    for(c) ch:
        if ch.key.mods != 0:
            prompt += " "
        prompt+= ch.key.to_string()
    prompt += " (escape to cancel)"


    return direction_prompt<P>{
        result: nil, 
        choices: c,
        prompt: prompt
    }
        
