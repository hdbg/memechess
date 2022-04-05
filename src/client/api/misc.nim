import std/jsffi

{.push nodecl, importc.}
proc setInterval*(callback: proc(args: varargs[JsObject]), delay: cint, args: varargs[JsObject]): cint
{.pop.}
