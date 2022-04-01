import std/[dom, jsffi]
import api

type
  TerminalCfg = object
    greetings, name, prompt: cstring
    height, width: cuint


  EvilUI* = ref object
    anchor: Element

proc cmdHandler(ui: EvilUi, cmd: cstring) =
  echo cmd

proc newUI*(): EvilUI =
  new result

  var ancestorRaw = document.getElementsByClassName("game__meta")

  if ancestorRaw.len != 1:
    raise ValueError.newException("Can't find ui root")

  var ancestor = ancestorRaw[0]

  result.anchor = document.createElement("div")
  result.anchor.setAttribute("class", "fish-gui")

  ancestor.appendChild(result.anchor)

  var fishTermCf = TerminalCfg(greetings:"EvilFish Control Panel",
      name:"evilfish", height:200, width:450, prompt:"fish> ")

  var this = result

  proc initTerm(d: proc(s: cstring): JsObject, undefined: JsObject) =
    var q = d(".fish-gui")

    q.terminal(proc (cmd: cstring) = this.cmdHandler(cmd), fishTermCf)

  jq(initTerm)

  result

