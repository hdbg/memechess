import std/[dom, jsffi, options, jsconsole]
import jquery

type
  Callback = proc(cmd: string)

  TerminalEchoOptions* = object
    raw*: bool # Allow display raw html
    finalize*: Option[proc(container: Element)]
    flush*: bool
    wrap*: Option[bool]
    keepWords*: bool
    newline*: bool

  # FormatOptions* = enum
  #   foUnderLine
  #   foStrike
  #   foOverline
  #   foItalic
  #   foBold
  #   foGlow
  #   foLink
  #   foImage

  TerminalCfg* = object
    greetings*, name*, prompt*: cstring
    height*, width*: cuint

  Terminal* = ref object of JsObject


proc newTerminal*(selector: JsObject, cfg: TerminalCfg, callback: Callback): Terminal =
  jQuery(
    proc (d: JqDollar, undefined: JsObject) =
    var q = d(selector.toJs)
    q.terminal(callback, cfg)
  )

  var raw = $$(selector)
  result = to(raw.terminal(), Terminal)


{.push nodecl.}
proc autologin(term: Terminal, username, password: cstring): auto {.importjs: "#.autologin(@)".}
proc before_cursor(term: Terminal, b: bool): cstring {.importjs: "#.before_cursor(@)".}
proc clear(term: Terminal) {.importjs: "#.clear(@)".}
proc clear_history_state(term: Terminal) {.importjs: "#.clear_history_state(@)".}
proc cols(term: Terminal): cuint {.importjs: "#.cols(@)".}
proc rows(term: Terminal): cuint {.importjs: "#.rows(@)".}
proc destroy(term: Terminal) {.importjs: "#.destroy(@)".}
proc display_position(pos: cuint, relative: bool = false) {.importjs: "#.display_position(@)".}
proc echo(term: Terminal, text: cstring) {.importjs: "#.echo(@)".}
proc enable(term: Terminal) {.importjs: "#.enable(@)".}
proc disable(term: Terminal) {.importjs: "#.disable(@)".}
proc error(term: Terminal, text: cstring) {.importjs: "#.error(@)".}
  # TODO: Exception
proc exec(term: Terminal, command: cstring, display: bool = true) {.importjs: "#.exec(@)".}
  # TODO: export_view
proc flush(term: Terminal) {.importjs: "#.flush(@)".}
proc freeze(term: Terminal, state: bool) {.importjs: "#.freeze(@)".}
proc get_command(term: Terminal): cstring {.importjs: "#.get_command(@)".}
proc pause(term: Terminal, visible: bool = false) {.importjs: "#.pause(@)".}
proc resume(term: Terminal) {.importjs: "#.resume(@)".}
{.pop.}
