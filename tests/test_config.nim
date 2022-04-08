import unittest2

include chess/config

suite "Config test":


  test "Load":
    const exampleJson = """{"kind":"cmLegit", "events":[]} """

    let tempFile = open("tm.json", fmReadWrite)

    tempFile.write(exampleJson)

    tempFile.close()

    let config = newConfig("tm.json")

    echo $(%config)





