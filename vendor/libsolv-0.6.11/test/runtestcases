#!/bin/bash

cmd=$1
dir=$2

if test -z "$cmd" -o -z "$dir"; then
  echo "Usage: runtestcases <cmd> <dir>";
  exit 1
fi

ex=0
for tc in $(find $dir -name \*.t) ; do
  $cmd $tc >/dev/null
  tex=$?
  tcn="${tc#$dir/} .................................................."
  tcn="${tcn:0:50}"
  if test "$tex" -eq 0 ; then
    echo "$tcn   Passed"
  elif test "$tex" -eq 77 ; then
    echo "$tcn   Skipped"
  else
    echo "$tcn***Failed"
    ex=1
  fi
done
exit $ex
