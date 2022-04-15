import std/jsffi

type
  HTMLAudioElement* = JsObject

proc newAudio*(link: cstring): HTMLAudioElement {.importjs: "new Audio(#)", nodecl.}
proc play*(audio: HTMLAudioElement) {.importjs: "#.play()", nodecl.}

{.push nodecl, importc.}
proc setInterval*(callback: proc(), delay: cint, args: varargs[JsObject]): cint
proc setTimeout*(callback: proc(), delay: cuint)
{.pop.}
