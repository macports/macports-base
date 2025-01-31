# Content

This directory contains all the files nedded to generate `modules/textutil/wcswidth.tcl` from the
associated Unicode database file.

These are

  1. `EastAsianWidth.txt`, the unicode database file itself, and
  2. `build.tcl`, the script to generate the code from the previous

The sub directory `alternates` contains the research undertaken to choose the current
implementation. This includes various alternate build scripts, generated code, benchmarking scripts,
and their results.
