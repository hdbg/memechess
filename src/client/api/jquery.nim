import std/jsffi

type
  JqDollar* = proc(selector: JsObject): JsObject
  JqCallback* = proc(d:JqDollar, undefined: JsObject)

proc jQuery*(callback: JqCallback) {.importjs: "jQuery(#)".}
proc `$$`*(selector: JsObject): JsObject {.importjs: "jQuery(#)".}
