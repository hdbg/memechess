import std/jsffi

type Object* = ref object of JsRoot
var
  ObjectManager* {.importc: "Object", nodecl.}: Object
  window* {.importc, nodecl.}: JsObject
  jQuery*{.importc, nodecl.}: JsObject



proc defineProperty*(mng: Object, target: JsObject, property: cstring,
    value: auto) {.importjs: "#.defineProperty(@)", nodecl.}


proc jq*(callback: proc(d: proc(s: cstring): JsObject, undefined: JsObject)) {.importjs: "jQuery(#)".}

# proc convert(x: JsObject, t: typedesc) =
