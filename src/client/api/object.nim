import std/jsffi

type Object* = ref object of JsRoot
var ObjectManager* {.importc: "Object", nodecl.}: Object

proc defineProperty*(mng: Object, target: JsObject, property: cstring,
    value: auto) {.importjs: "#.defineProperty(@)", nodecl.}
