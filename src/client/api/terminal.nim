import std/[dom, jsffi, options]
import jquery

type
  TerminalEchoOptions* = ref object
    raw: bool = false # Allow display raw html
    finalize: Option[proc(container: Element)]
    flush: bool = true
    wrap: Option[bool]
    keepWords: bool = false
    newline: bool = true

  TerminalCfg* = object
    greetings, name, prompt: cstring
    height, width: cuint

  Terminal* = ref object of JsObject


proc initTerminalConfig*(height, width: cuint): TerminalCfg = TerminalCfg(
    height: height, width: width)

proc newTerminalEchoOptions(): TerminalEchoOptions = new result

proc newTerminal*(selector: JsObject, callback: proc(cmd: cstring),
    cfg: TerminalCfg): Terminal =
  new result

  # var ancestorRaw = document.getElementsByClassName("game__meta")

  # if ancestorRaw.len != 1:
  #   raise ValueError.newException("Can't find ui root")

  # var ancestor = ancestorRaw[0]

  # result.anchor = document.createElement("div")
  # result.anchor.setAttribute("class", "fish-gui")

  # ancestor.appendChild(result.anchor)
  jQuery(
    proc (d: jqDollar, undefined: JsObject) =
    var q = d(selector.toJs)

    q.terminal(callback, cfg)
  )

  result = jq(selector.toJs).terminal()

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
