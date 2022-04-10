import std/jsffi

{.push nodecl, importc.}
proc setInterval*(callback: proc(), delay: cint, args: varargs[JsObject]): cint
proc setTimeout*(callback: proc(), delay: cuint)
{.pop.}
