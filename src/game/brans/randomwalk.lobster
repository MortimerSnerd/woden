// Simple random walk thinker, for test purposes.
import core.algs
import game.brans
import game.actions
import game.objects

class randomwalker: thinker
    obj: object_instance

    def next_action() -> action_desc?, action_state?:
        let move = find_action("move")
        guard move and move is move_action:
            // NB slightly ugly, have to do is test so we know correct validate method
            return nil, nil

        let choices = []
        let st = action_state{who: obj, what: nil, where: int2_0}
        for(all_dirs) dir:
            if move.validate(obj, dir+obj.cc, st):
                push(choices, dir)

        if length(choices) > 0:
            let chdir = rnd_pick(choices)
            move.validate(obj, chdir+obj.cc, st)  // init st with state for this move
            return move, st
        else:
            return nil, nil

        

