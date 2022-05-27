import unittest2
import shared/[frames, proto]
import std/options

suite "FramesHandler":
  test "Framing and parsing":
    var fh = FramesHandler()
    addHandler[Step](
      fh,
      proc (step: Step) =
        check: step.ply == 20
    )

    let data = framify(Step(ply:20))

    fh.dispatch(data)

  test "More convienient notation":
    var fh = FramesHandler()

    fh.handle(Step):
      check: data.san.get == "a2a4"

    let data = framify(Step(san: some("a2a4")))
    fh.dispatch(data)


  test "Do notation for callback":
    var fh = FramesHandler()

    fh.addHandler() do(data: Step):
      check: data.san.get == "b2b4"

    let data = framify(Step(san: some("b2b4")))
    fh.dispatch(data)

