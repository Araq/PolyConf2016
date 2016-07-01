
when defined(iter):
  iterator countdown2(a, b: int): int {.closure.} =
    var x = a
    while x >= b:
      yield x
      x -= 1

  var it = countdown2
  while true:
    let x = it(10, 0)
    if finished(it): break
    echo x

when defined(main):
  proc main =
    var mystr = "Hello"
    mystr.add " World!"
    if mystr != "Hello World":
      quit "bug?"
    echo mystr

  main()

when defined(assert):
  import macros

  macro assert2(cond, msg: untyped): untyped =
    let body = newCall(bindSym"quit", msg)
    result = newNimNode(nnkIfStmt)
    result.add(newNimNode(nnkElifBranch).add(
      newCall(bindSym"not", cond), body))
    echo treeRepr result

  assert2 mystr == "Would you kindly", "bug!"
