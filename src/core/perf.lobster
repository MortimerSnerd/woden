// Simple timing functions to help shake out problems.
import core.logging

class stopwatch:
   what = [] :: string
   t0 = [] :: float

   def start(desc: string):
      push(t0, seconds_elapsed())
      push(what, desc)

   def stop():
      let t1 = seconds_elapsed()
      let t = pop(t0)
      let w = pop(what)
      let ind = repeat_string("  ", length(what))
      timing(): "{ind}{w} - {t1-t}"

   def time(desc: string, body):
      start(desc)
      body()
      stop()

