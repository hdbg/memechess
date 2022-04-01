import std/dom

type
  EvilUI* = ref object
    anchor: Element

proc newUI*(): EvilUI =
  new result

  var ancestor = document.getElementsByClassName("game__meta")

  if ancestor.len != 1:
    raise ValueError.newException("Can't find ui root")
  else:
    ancestor = ancestor[0]

  result.anchor = dom.createElememt("div")
  result.anchor.setAtrribute("class", "fish-gui")

  ancestor.addChild(result)

