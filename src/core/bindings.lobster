// Generic keybinding support.  Can present to the user what keys are being 
// monitored for what actions.
import core.kvpair
import core.logging

enum_flags modifiers:
   mod_shift, mod_control, mod_alt

//TODO support wheel-up and wheel-down

enum key_tests:
   key_is_up, key_is_down,       // Key is up/down, even if it just went down.
   key_went_down, key_went_up    // Only true on frame key transitions up/down

let key_test_desc = ["up", "down", "pressed", "released"]

// Description of a key combination. In addition to keys recognized by gl_button,
// also recognizes "mouse wheel up" and "mouse wheel down"
class key_desc:
   mods: int    // modifiers, like mod_control, etc.
   key: string  // Key recognized by gl_button().  

   def to_string():
      var rv = ""
      if mods.has(mod_control):
         rv += "Ctrl-"
      if mods.has(mod_alt):
         rv += "Alt-"
      if mods.has(mod_shift):
         rv += "Shift-"
      rv += key
      return rv

   def same_as(other):
      return mods == other.mods and key == other.key

   // Compares key test and the output of gl_button, returning true 
   // if the test should pass.
   def key_test_passes(test: key_tests):
      if key == "mouse wheel up" or key == "mouse wheel down":
         return gl_mousewheel_delta() != 0
      else:
         let downv, upv = gl_button(key)
         switch test:
            case key_is_up:
               return upv >= 1
            case key_is_down:
               return downv >= 1
            case key_went_down:
               return downv == 1
            case key_went_up:
               return upv == 1
            default:
               return false

   // Returns true if the mod state matches the spec in mods.
   private def mods_match(mod_flag, but1, but2) -> bool:
      if mods.has_any(mod_flag):
         return gl_button(but1) != 0 or gl_button(but2) != 0
      else:
         return gl_button(but1) == 0 and gl_button(but2) == 0

   // Returns an activation count >= 1  if the particular key test passes.
   def test(kt: key_tests) -> int:
      if key_test_passes(kt):
         if not mods_match(mod_shift, "left shift", "right shift"):
            return 0
         elif not mods_match(mod_control, "left ctrl", "right ctrl"):
            return 0
         elif not mods_match(mod_alt, "left alt", "right alt"):
            return 0
         else:
            if key == "mouse wheel up":
               return max(0, gl_mousewheel_delta())
            elif key == "mouse wheel down":
               return abs(min(0, gl_mousewheel_delta()))
            else:
               return 1
      else:
         return 0


// Set of key bindings.
class binding_set:
   // If true, binding searches will check the previous set of pushed
   // bindings.
   include_previous: bool = false

   prev: binding_set? = nil

   // If true, allows different actions to bind to the same key.
   // Helpful for context sensitive binding checks.
   allow_duplicates = false

   // Previous set of bindings 
   // Bindings from action name to a key description.
   key_bindings = [] :: kvpair<string, key_desc>

   // Binds a key to an action.  If the key was bound
   // to another action, that binding is removed, and the
   // unbound action is returned, otherwise returns "".
   def bind(action: string, key: key_desc) -> string:
      let prev_bind = find(key_bindings) p: p.value.same_as(key)
      var rv = ""
      if not allow_duplicates and prev_bind >= 0:
         rv = key_bindings[prev_bind].key
         remove(key_bindings, prev_bind)
      push(key_bindings, kvpair<string, key_desc>{action, key})
      return rv

   // Returns the key_desc for a given action, if any.
   def key_for_action(action: string) -> key_desc?:
      let i = findkv(key_bindings, action)
      if i >= 0:
         return key_bindings[i].value
      elif include_previous and prev != nil:
         return prev.key_for_action(action)
      else:
         return nil

// Stack of bindings, active on top.
private var bindings: binding_set? = nil

// Push and activate a set of key bindings.
def push_bindings(bs: binding_set):
   bs.prev = bindings
   bindings = bs

// Pop the last pushed key bindings.
def pop_bindings() -> binding_set?:
   if bindings != nil:
      let rv = bindings
      bindings = bindings.prev
      return rv
   else:
      return nil

// List of all actions and the type of key tests made for this frame.
private var frame_tests = [] :: kvpair<string, key_tests>

// Performs a test for a key binding, calling body(activation_count)
// if the test passes.  activation_count is 1 for regular keys, can be
// > for mouse wheel. 
def when_binding(test: key_tests, action: string, body):
   push(frame_tests, kvpair<string, key_tests>{action, test})
   if bindings != nil:
      let key = bindings.key_for_action(action)
      if key:
         let a_c = key.test(test)
         if a_c > 0:
            body(a_c)
      else:
         warn(): "when_binding: unbound action: {action}"

// Should be called at the beginning of the frame before any when_binding calls
// are made.
def bindings_begin_frame():
   frame_tests = []

// Iterates through all bindings actively being checked, calling 
// body(action, test, key_desc).  Does not work correctly if bindings
// have been pushed/popped during the frame.
def for_tested_bindings(body):
   for(frame_tests) p:
      if bindings != nil:
         let key = bindings.key_for_action(p.key)
         if key != nil:
            body(p.key, p.value, key)

