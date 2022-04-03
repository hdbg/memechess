import std/jsffi

type
  JqDollar* = proc(selector: JsObject): JsObject
  JqCallback* = proc(d:JqDollar, undefined: JsObject)

proc jQuery*(callback: JqCallback) {.importjs: "jQuery(#)".}
proc jq*(selector: JsObject): JsObject {.importjs: "$$(#)".}
