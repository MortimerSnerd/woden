// Timed events, and ways to chain them.
//

//have animator take orchestrator so we can fire events when a frame is hit.
//ex: soda machine about to explode animation sends an event when it does explode.

private let keys_per_event = 2
private let prealloc = 50
private let deleted_key = -12345678  // worst. sentinel. ever.
private def key_ix(ei: int) -> int: return ei * keys_per_event

// Class that holds all of the orchestration state.  
// Done this way to make including things in the debugger
// gui easy, no other compelling reason.
class orchestrator:
   // Indices for free event entries.
   ev_free: [int] 

   // Game time left in seconds before event.
   ev_time: [float]

   // User supplied keys for events, more than one per event.
   ev_keys: [int]

   // For event that have fired, sequences of keys_per_event keys for the fired
   // event.  These are cleared on every frame, so callers need to check them 
   // every frame with for_fired_events.
   fired: [int]

   // Free the event with the given index.
   private def delete_event(ei: int):
      assert ei < length(ev_time)
      assert ev_keys[ei*keys_per_event] != deleted_key
      push(ev_free, ei)
      ev_keys[ei*keys_per_event] = deleted_key
      ev_time[ei] = -1.0

   // Schedule a event +dt seconds in the future.  
   // key1 and key2 just need to be meaningful to the caller, 
   // they need not be unique.
   def sched_event(dt: float, key1: int, key2: int = -1):
      assert key1 != deleted_key
      if length(ev_free) > 0:
         let rv = pop(ev_free)
         let ki = key_ix(rv)
         ev_time[rv] = dt
         ev_keys[ki] = key1
         ev_keys[ki+1] = key2
      else:
         push(ev_time, dt)
         push(ev_keys, key1)
         push(ev_keys, key2)

   // Fires an event immediately.  For events that don't need to 
   // be scheduled, like a animation frame event.  Does not change
   // any scheduled events.
   def fire_event(key1: int, key2: int = -1):
      push(fired, key1)
      push(fired, key2)

   // Iterates all fired indices.  Does not skip canceled 
   // fired events.
   private def iterate_fired_ix(body):
      var fi = 0
      while fi < length(fired):
         body(fi)
         fi += keys_per_event

   // Cancel any events where key == ev_keys[ei+koffset].
   private def intern_cancel_event(key: int, koffset: int):
      for(length(ev_time)) ei:
         let ki = key_ix(ei)
         let ktest = ev_keys[ki+koffset]
         if  ev_keys[ki] != deleted_key and ktest == key:
            delete_event(ei)

      // Mark the matching fired events as cancelled.
      iterate_fired_ix() fi:
         if fired[fi+koffset] == key:
            fired[fi] = deleted_key

   // Cancels any events where key matches key1 of the event.
   def cancel_event_key1(key: int):
      intern_cancel_event(key, 0)

   // Cancels any events where key matches key1 of the event.
   def cancel_event_key2(key: int):
      intern_cancel_event(key, 1)

   // Iterate fired events from the last call to update_events(), 
   // calling body(key1, key2)
   def for_fired_events(body):
      iterate_fired_ix() fi:
         if fired[fi] != deleted_key:
            body(fired[fi], fired[fi+1])

   // Test if a particular event has fired.  Better to batch handle
   // events with for_fired_events(), but this works for occasional tests.
   def event_fired(k1: int):
      for_fired_events() ev, k2:
         if ev == k1:
            return true from event_fired

      return false

   // Called once per frame the change in game time from the last frame.
   def update_events(dt: float):
      fired = []
      for(ev_time) tleft, ei:
         if tleft >= 0.0:
            ev_time[ei] -= dt
            if ev_time[ei] <= 0.0:
               let ki = key_ix(ei)
               push(fired, ev_keys[ki])
               push(fired, ev_keys[ki+1])
               delete_event(ei)
            

// Creates a new orchestrator.
def mk_orchestrator():
   return orchestrator{
      ev_free: vector_capacity([], prealloc),
      ev_time: vector_capacity([], prealloc),
      ev_keys: vector_capacity([], prealloc*keys_per_event),
      fired: [],
   }

