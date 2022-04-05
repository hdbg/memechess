import std/[dom, jsffi, options, jsconsole]
import jquery

type
  TerminalEchoOptions* = object
    raw*: bool # Allow display raw html
    finalize*: Option[proc(container: Element)]
    flush*: bool
    wrap*: Option[bool]
    keepWords*: bool
    newline*: bool

  TerminalCfg* = object
    greetings*, name*, prompt*: cstring
    height*, width*: cuint

  Terminal* = ref object of JsObject


proc newTerminal*(selector: JsObject, callback: proc(cmd: string),
    cfg: TerminalCfg): Terminal =

  jQuery(
    proc (d: JqDollar, undefined: JsObject) =
    var q = d(selector.toJs)

    q.terminal(callback, cfg)
  )

  var raw = $$(selector)

  result = to(raw.terminal(), Terminal)

when false:
  {.push nodecl.}
  proc autologin(term: Terminal, username, password: cstring): auto {.importjs.}
  proc before_cursor(term: Terminal, b: bool): cstring {.importjs: "#.before_cursor(@)".}
  proc clear(term: Terminal) {.importjs: "#.clear(@)".}
  proc clear_history_state(term: Terminal) {.importjs.}
  proc cols(term: Terminal): cuint {.importjs.}
  proc rows(term: Terminal): cuint {.importjs.}
  proc destroy(term: Terminal) {.importjs.}
  proc display_position(pos: cuint, relative: bool = false) {.importjs.}
  proc echo(term: Terminal, text: cstring, preferences: TerminalEchoOptions = newTerminalEchoOptions()) {.importjs.}
  proc enable(term: Terminal) {.importjs.}
  proc disable(term: Terminal) {.importjs.}
  proc error(term: Terminal, text: cstring) {.importjs.}
  # TODO: Exception
  proc exec(term: Terminal, command: cstring, display: bool = true) {.importjs.}
  # TODO: export_view
  proc flush(term: Terminal) {.importjs.}
  proc freeze(term: Terminal, state: bool) {.importjs.}
  proc get_command(term: Terminal): cstring {.importjs.}
  proc pause(term: Terminal, visible: bool = false) {.importjs.}
  proc resume(term: Terminal) {.importjs.}
  {.pop.}
