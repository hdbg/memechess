import unittest2
import shared/[handler, proto]

suite "test FramesHandler":
  var fh = new FramesHandler

  test "ChessStep":
    addHandler[ChessStep](
      fh,
      proc (step: ChessStep) =
        assert step.ply == 20
        echo step
    )

    let data = framify(ChessStep(ply:20))

    echo data

    fh.handle(data)
