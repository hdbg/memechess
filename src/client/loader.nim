import std/[jsffi, jsconsole]
import api
import shellcode


when isMainModule:
  type
    Overrider = object
      get: proc(): JsObject
      set: proc(obj: JsObject): JsObject


  proc execApp(obj: JsObject, opts: JsObject): JsObject {.importjs: "#(@)", nodecl.}

  var
    lrCopy: JsObject
    lr: JsObject

  let interceptObject = Overrider(
    get:
    proc(): JsObject = lr,
    set:
    proc(obj: JsObject): JsObject =
      lr = obj

      lrCopy = lr.app

      lr.app =
        proc(opts: JsObject): JsObject =
          var resp = lrCopy.execApp(opts)

          window.Bot = newShellCode(resp.moveOn.ctrl, opts)

          resp
    )

  ObjectManager.defineProperty(window, "LichessRound", interceptObject)
