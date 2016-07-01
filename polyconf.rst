==========================
   Nim async voodoo
==========================



.. raw:: html

  <p class="pic"><img alt="UE4 Screenshot" src="unrealengine4.png" scale="60%" /></p>


..
  - unpack macro
  Nim async voodoo

  ABSTRACT
  Nim is a quite unique programming language that focusses on meta programming
  by giving you one of the most powerful macro systems. In this talk we will
  look at how Nim's macro system gives us a high performance asynchronous IO
  framework. In other words what is usually built into a language core can be
  an ordinary library extension in Nim.

  PRIVATE ABSTRACT
  Outline:

  Explain Nim and the basics of Nim's macro system.
  Show a few async/await examples.
  Show Nim's "closure iterators".
  Show how the 'async' macro translates Nim code into closure iterators.
  Show how the async main loop looks like under the hood.
  Explain Nim's memory management with its thread local heaps.
  Perhaps show some benchmarks.
  HISTORY
  This talk is novel and has never been performed before.



What's Nim?
===========

- compiles to C++/Objective C/C/JavaScript
- statically typed
- "systems" programming
- Python inspired syntax


A bug
=====

.. code-block:: nim
   :number-lines:

  proc main =
    var mystr = "Would you"
    mystr.add " kindly?"
    if mystr != "Would you kindly":
      quit "bug!"
    echo mystr

  main()

A bug
=====

.. code-block:: nim
   :number-lines:

  proc main =
    var mystr = "Would you"
    mystr.add " kindly?"
    if mystr != "Would you kindly":
      quit "bug!"
    echo mystr

  main()

output::
  bug!


Assert
======

.. code-block:: nim
   :number-lines:

  proc main =
    var mystr = "Would you"
    mystr.add " kindly?"
    assert mystr == "Would you kindly", "bug!"
    echo mystr

  main()


Assert
======

.. code-block:: nim
   :number-lines:

  template assert(cond, msg: untyped) =
    if not cond:
      quit msg


Assert
======

Desired output::
  Expected: Would you kindly
  But got: Would you kindly?


Assert
======

.. code-block:: nim
   :number-lines:

  import macros

  macro assert(cond, msg: untyped): untyped =
    let body = newCall(bindSym"quit", msg)
    result = newNimNode(nnkIfStmt)
    result.add(newNimNode(nnkElifBranch).add(
      newCall(bindSym"not", cond), body))
    echo treeRepr result

Trees
=====

AST::
  IfStmt
    ElifBranch
      Call
        Sym "not"
        Infix
          Ident !"=="
          Ident !"mystr"
          StrLit Hello World
      Call
        ClosedSymChoice
          Sym "quit"
          Sym "quit"
        StrLit bug!

Assert
======

.. code-block:: nim
   :number-lines:

  import macros

  macro assert(cond, msg: untyped): untyped =
    template helper(cond, msg) =
      if not cond:
        quit msg
    result = getAst(helper(cond, msg))


Assert
======

.. code-block:: nim
   :number-lines:

  import macros

  macro assert(cond, msg: untyped): untyped =
    template fallback(cond, msg) =
      if not cond:
        quit msg

    template cmp(cond, a, b, msg) =
      if not cond:
        echo "Expected: ", b
        echo "But got: ", a
        quit msg

    if cond.kind in nnkCallKinds and cond.len == 3 and
        $cond[0] in ["==", "<=", "<", ">=", ">", "!="]:
      result = getAst(cmp(cond, cond[1], cond[2], msg))
    else:
      result = getAst(fallback(cond, msg))


Sequential Paradise
===================

.. code-block:: nim
   :number-lines:

  proc downloadSync(url: string): string =
    result = "implementation missing"

  proc main() =
    let a = downloadSync(siteA)
    let b = downloadSync(siteB)
    let c = downloadSync(siteC)
    echo a & b & c


Sequential Paradise
===================

.. code-block:: nim
   :number-lines:

  proc downloadSync(url: string): string =
    result = "implementation missing"

  proc main() =
    let a = ***downloadSync(siteA)***
    let b = downloadSync(siteB)
    let c = downloadSync(siteC)
    echo a & b & c

Sequential Paradise
===================

.. code-block:: nim
   :number-lines:

  proc downloadSync(url: string): string =
    result = "implementation missing"

  proc main() =
    let a = downloadSync(siteA)
    let b = ***downloadSync(siteB)***
    let c = downloadSync(siteC)
    echo a & b & c

Sequential Paradise
===================

.. code-block:: nim
   :number-lines:

  proc downloadSync(url: string): string =
    result = "implementation missing"

  proc main() =
    let a = downloadSync(siteA)
    let b = downloadSync(siteB)
    let c = ***downloadSync(siteC)***
    echo a & b & c


Callback Hell
=============

.. code-block:: nim
   :number-lines:

  proc downloadAsync(url: string; oncomplete: proc(html: string)) =
    oncomplete("implementation missing")

  proc main() =
    downloadAsync(siteA, proc(a: string) =
      downloadAsync(siteB, proc (b: string) =
        downloadAsync(siteC, proc (c: string) =
          echo a & b & c
        )))




Yield
=====

.. code-block:: nim
   :number-lines:

  # Warning: Pseude-code ahead!

  proc main =
    let a = download(siteA)
    return
    on resume:
      let b = download(siteB)
      return
    on resume:
      let c = download(siteC)
      return
    on resume:
      echo a & b & c


Yield (2)
=========

.. code-block:: nim
   :number-lines:

  proc main =
    let a = download(siteA)
    yield
    let b = download(siteB)
    yield
    let c = download(siteC)
    yield
    echo a & b & c


State machines
==============

.. code-block:: nim
   :number-lines:

  var state = 0 # cannot be put on the stack :-(
  var a, b, c: string
  proc main(html: string) =
    case state
    of 0:
      state = 1
      downloadAsync(siteA, main)
    of 1:
      state = 2
      a = html
      downloadAsync(siteB, main)
    of 2:
      state = 3
      b = html
      downloadAsync(siteC, main)
    else:
      c = html
      echo a & b & c




Iterators
=========

.. code-block:: nim
   :number-lines:

  iterator countdown(a, b: int): int {.closure.} =
    var x = a
    while x >= b:
      yield x
      x -= 1

  for x in countdown(10, 0):
    echo x


Iterators
=========

.. code-block:: nim
   :number-lines:

  iterator countdown(a, b: int): int {.closure.} =
    var x = a
    while x >= b:
      yield x
      x -= 1

  var inst = countdown
  while true:
    let x = inst(10, 0)
    if finished(inst): break
    echo x


Iterators
=========

.. code-block:: nim
   :number-lines:

  type
    Future = ref object
      result: string

  iterator main(): Future {.closure.} =
    yield requestDownload(siteA)
    yield requestDownload(siteB)
    yield requestDownload(siteC)
    echo a.result & b.result & c.result


Futures
=======

.. code-block:: nim
   :number-lines:

  type
    FutureBase = ref object of RootObj ## Untyped future.
      cb: proc () {.closure.}
      finished: bool
      error: ref Exception
      when not defined(release):
        stackTrace: string
        id: int
        fromProc: string

    Future[T] = ref object of FutureBase ## Typed future.
      value: T ## Stored value


..
  Futures (2)
  ===========

  .. code-block:: nim
     :number-lines:

    proc `and`[T, Y](fut1: Future[T], fut2: Future[Y]): Future[void] =
      ## Returns a future which will complete once both ``fut1`` and ``fut2``
      ## complete.
      var retFuture = newFuture[void]("asyncdispatch.`and`")
      fut1.callback =
        proc () =
          if fut2.finished: retFuture.complete()
      fut2.callback =
        proc () =
          if fut1.finished: retFuture.complete()
      return retFuture

    proc `or`[T, Y](fut1: Future[T], fut2: Future[Y]): Future[void] =
      ## Returns a future which will complete once either ``fut1`` or ``fut2``
      ## complete.
      var retFuture = newFuture[void]("asyncdispatch.`or`")
      proc cb() =
        if not retFuture.finished: retFuture.complete()
      fut1.callback = cb
      fut2.callback = cb
      return retFuture


Async & await
=============

.. code-block:: nim
   :number-lines:

  import httpclient, asyncdispatch

  proc main() {.async.} =
    var client = newAsyncHttpClient()
    var a = await client.request("http://nim-lang.org")
    var b = await client.request("http://nim-lang.org/docs/tut1.html")
    var c = await client.request("http://nim-lang.org/docs/tut2.html")

    echo a.body & b.body & c.body

  waitFor main()


Async & await
=============

.. code-block:: nim
   :number-lines:

  import httpclient, asyncdispatch

  proc main() {.async.} =
    var client = newAsyncHttpClient()
    var resp = await client.request("http://nim-lang.org")
    echo resp.body

  waitFor main()


Async & await
=============

.. code-block:: nim
   :number-lines:

  proc main(): Future[void] =
    var retFuture = newFuture[void]()
    iterator mainIter(): FutureBase {.closure.} =
      var client = newAsyncHttpClient()
      var future = client.request("http://nim-lang.org")
      yield future
      var resp = future.read
      echo resp.body
      complete(retFuture)

    createCb(retFuture, mainIter)
    return retFuture


createCb
========

.. code-block:: nim
   :number-lines:

  template createCb(retFuture, iter: untyped): untyped =
    var instance = iter
    proc singleStep =
      try:
        var next = instance()
        if not finished(instance):
          next.cb = singleStep
          if finished(next):
            schedule(next.cb)
      except:
        if retFuture.finished:
          raise
        else:
          retFuture.fail(getCurrentException())
    singleStep()


Async macro
===========

* transform the return type ``T`` to ``Future[T]``
* put the proc body into an inner ``iterator``
* transform ``return`` to ``complete(retFuture); return``
* do something with ``try``
* transform the ``await`` to a ``yield``


Async macro
===========

.. code-block:: nim
   :number-lines:

  proc transformBody(n: NimNode): NimNode =
    template tyield(expr): untyped =
      var future = expr
      yield future
      var resp = future.read
      resp

    if n.kind in nnkCallKinds and n[0].eqIdent == "await":
      expectLen(n, 2)
      result = getAst tyield(n[1])
    else:
      # recurse:
      result = n
      for i in 0 ..< result.len:
        result[i] = transformBody(result[i])



Event loop
==========

.. code-block:: nim
   :number-lines:

  type FileHandle = distinct int

  proc epoll(handles: var seq[FileHandle]) = discard "provided by OS"


  var
    tasks: Table[FileHandle, FutureBase]

  proc schedule(f: FutureBase) =
    tasks[f.determineHandle] = f

  proc scheduler() =
    while true:
      var handles: seq[FileHandle]
      prepareHandles(handles, tasks)
      epoll(handles)
      for h in handles:
        tasks[h].cb()



Whetting your appetite
======================

.. code-block:: nim
   :number-lines:

  import httpclient, asyncdispatch

  proc main() {.autoAsync.} =
    var client = newAsyncHttpClient()
    var a = request(client, "http://nim-lang.org")
    var b = request(client, "http://nim-lang.org/docs/tut1.html")
    var c = request(client, "http://nim-lang.org/docs/tut2.html")

    echo a.body & b.body & c.body

  waitFor main()


Whetting your appetite
======================

.. code-block:: nim
   :number-lines:

  proc transformBody(n: NimNode): NimNode =
    template tyield(expr): untyped =
      ...

    proc inAwaitContext(op: string): bool =
      op.startsWith("read") or op.startsWith("write") or op.startsWith("request")

    if n.kind in nnkCallKinds and inAwaitContext($n[0]):
      result = getAst tyield(n)
    else:
      # recurse:
      result = n
      for i in 0 ..< result.len:
        result[i] = transformBody(result[i])


Survey
======

http://nim-lang.org/news/2016_06_23_launching_the_2016_nim_community_survey.html

http://bit.ly/29g8rFn

http://nim-lang.org/survey


Please contribute
=================

============       ================================================
Slides             https://github.com/Araq/PolyConf2016
Website            http://nim-lang.org
Mailing list       http://www.freelists.org/list/nim-dev
Forum              http://forum.nim-lang.org
Github             https://github.com/nim-lang/Nim
IRC                irc.freenode.net/nim
UE4                https://github.com/pragmagic/nimue4
============       ================================================


Nim in Action
=============

.. raw:: html

  <p class="pic"><img alt="Nim in Action Screenshot" src="nim_in_action.png" scale=100% /></p>

http://nim-lang.org/manning

