
import os, strutils

proc main(cmd: string) =
  for f in walkDirRec(getCurrentDir()):
    if ".git" in f or "nimcache" in f or f.endsWith".exe": continue
    let e = cmd & " " & f
    echo e
    if execShellCmd(e) != 0:
      echo "failed ", e

main(paramStr(1))
