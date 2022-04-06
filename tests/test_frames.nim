import unittest2
import shared/[frames, proto]
import std/options

suite "test FramesHandler":
  test "Framing and parsing":
    var fh = FramesHandler()
    addHandler[ChessStep](
      fh,
      proc (step: ChessStep) =
        assert step.ply == 20
        echo step
    )

    let data = framify(ChessStep(ply:20))

    echo data

    fh.dispatch(data)

  test "More convienient notation":
    var fh = FramesHandler()

    fh.handle(ChessStep):
      echo "Handler called, data: ", data

    let data = framify(ChessStep(san: some("a2a4")))

    echo data

    fh.dispatch(data)
