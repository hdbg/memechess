import std/[jsffi, options]

type ReflectApi = ref object of JsRoot
let Reflect* {.importc, nodecl.}: ReflectApi

{.push nodecl.}
proc apply*(api: ReflectApi, target: JsObject, this: JsObject, args: JsObject): JsObject {.importjs:"#.apply(@)"}
proc defineProperty*(api: ReflectApi, target: JsObject, property: cstring, attrs: JsObject): bool {.importjs: "#.defineProperty(@)".}
proc get*[T: cint | cstring](api: ReflectApi, target: JsObject, property: T): JsObject {.importjs: "#.get(@)".}
proc set*[T: cint, cstring](api: ReflectApi, target: JsObject, property: T, value: JsObject, that: Option[JsObject] = none[JsObject]()) {.importjs: "#.set(@)".}
proc has*[T: cint, cstring](api: ReflectApi, target: JsObject, property: T): bool {.importjs: "#.has(@)"}
{.pop.}
