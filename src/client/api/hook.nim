import std/jsffi
import reflect

type
  JsFunc = proc(args: varargs[JsObject]): JsObject

  HookMode = enum hmBefore, hmAfter, hmReplace

  Hook = ref object
    this: JsObject
    original, callback: JsFunc

proc newHook(this: JsObject,mode: HookMode, orig, cb: JsFunc): Hook =
  let hook = Hook(this:this, original: orig, callback: cb)


