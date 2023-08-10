// Simple logging, with logging functions that delay message string creation
// in a function, so strings are only created when the message needs to 
// be logged.
enum_flags LogLevel:
   Error, 
   Warning, 
   Debug, 
   Timings, 
   StatLogs,
   HopLogs,
   AILogs,
   ControllerLogs

def ActionLogCb(msg: string) -> void
private var actionlog_cb: ActionLogCb = fn (msg: string) -> void: pass()

def logging_set_cb(cbfn):
   actionlog_cb = cbfn

var LoggingLevel: int = Error|Warning
let LogToActionLog = false

// Helper for setting the print depth just for logging.
def with_print_depth(d, body): 
   let old = set_print_depth(d)
   let rv = body()
   set_print_depth(old)
   return rv

def with_print_decimals(d, body):
   let old = set_print_decimals(d)
   body()
   set_print_decimals(old)

private def tstamp() -> string:
   let now = seconds_elapsed()
   let exlen = 5
   var ss = string(now)
   if length(ss) > exlen:
      ss = substring(ss, 0, exlen)

   while length(ss) < exlen:
      ss += " "

   return ss

def warn(f):
   if LoggingLevel & Warning:
      let msg = "{tstamp()} WARN: {f()}"
      print(msg)
      if LogToActionLog:
         actionlog_cb(msg)

def error(f):
   if LoggingLevel & Error:
      let msg = "{tstamp()} ERR:  {f()}"
      print(msg)
      if LogToActionLog:
         actionlog_cb(msg)

def debug(f):
   if LoggingLevel & Debug:
      let msg = "{tstamp()} DBG:  {f()}"
      print(msg)
      if LogToActionLog:
         actionlog_cb(msg)

def timing(f):
   if LoggingLevel & Timings:
      let msg = "{tstamp()} TIME: {f()}"
      print(msg)
      if LogToActionLog:
         actionlog_cb(msg)

def statlog(f):
   if LoggingLevel & StatLogs:
      let msg = "{tstamp()} STAT: {f()}"
      print(msg)
      if LogToActionLog:
         actionlog_cb(msg)

def hoplog(f):
   if LoggingLevel & HopLogs:
      let msg = "{tstamp()} HOP:  {f()}"
      print(msg)
      if LogToActionLog:
         actionlog_cb(msg)

def ailog(f):
   if LoggingLevel & AILogs:
      let msg = "{tstamp()} AI:   {f()}"
      print(msg)
      if LogToActionLog:
         actionlog_cb(msg)

def ctlmsg(f):
   if LoggingLevel & ControllerLogs:
      let msg = "{tstamp()} CTRL:   {f()}"
      print(msg)
      if LogToActionLog:
         actionlog_cb(msg)

// Temporarily turn off some logging levels
// for a scope.
def inhibiting_log(mask: int, body):
   let orig = LoggingLevel
   LoggingLevel = LoggingLevel & ~mask
   body()
   LoggingLevel = orig

