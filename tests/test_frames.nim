import unittest2
import shared/[frames, proto]
import std/options

suite "test FramesHandler":
  test "Framing and parsing":
    var fh = FramesHandler()
    addHandler[Step](
      fh,
      proc (step: Step) =
        assert step.ply == 20
        echo step
    )

    let data = framify(Step(ply:20))

    echo data

    fh.dispatch(data)

  test "More convienient notation":
    var fh = FramesHandler()

    fh.handle(Step):
      echo "Handler called, data: ", data

    let data = framify(Step(san: some("a2a4")))

    echo data

    fh.dispatch(data)

  test "Do notation for callback":
    var fh = FramesHandler()

    fh.addHandler() do(data: Step):
      echo data

    let data = framify(Step(san: some("b2b4")))
    echo data
    fh.dispatch(data)
