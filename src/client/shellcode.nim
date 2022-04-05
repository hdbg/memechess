import std/[jsffi, options, jsconsole, dom]

import api/[terminal, reflect, misc]
import shared/[proto, frames]

import jswebsockets

type
  ShellCode = ref object
    terminal: Terminal
    protocol: FramesHandler
    ws: jswebsockets.WebSocket

    # apiMove: proc(before, after: cstring)

    rawCtrl: JsObject
    rawOpts: JsObject


proc createAnchor(parent: string, child_id: string): Element =
  var ancestorRaw = document.getElementsByClassName(parent)

  if ancestorRaw.len != 1:
    raise ValueError.newException("Can't find ui root")
  var ancestor = ancestorRaw[0]

  var anchor = document.createElement("div")
  anchor.setAttribute("id", child_id)

  ancestor.appendChild(anchor)

  anchor

proc onCmd(sc: ShellCode, cmd: string) =
  var data = framify(TerminalInput(input: cmd)).cstring
  sc.ws.send data

proc newShellCode*(ctrl: JsObject, opts: JsObject): ShellCode =
  new result

  result.rawCtrl = ctrl
  result.rawOpts = opts
  result.protocol = FramesHandler()

  block ui:
    let terminalConfig = TerminalCfg(height: 100, width: 300)

    discard createAnchor("game__meta", "fish-gui")

    result.terminal = newTerminal("#fish-gui".toJs,
      proc(cmd: string) = result.onCmd(cmd),
      terminalConfig)


  #result.apiMove = to(Reflect.get(ctrl, "apiMove".cstring), typeof(result.apiMove))
  #Reflect.set(ctrl, "apiMove".cstring, toJs(proc(before, after: cstring) = console.log(before, after)))

  var ws = newWebsocket("ws://localhost:8080/fish")
  ws.onOpen = proc(event: Event) =
    console.log "socket open"
    discard setInterval(delay=400, callback=proc(args: varargs[JsObject]) =
      ws.send((framify Ping()).cstring))
