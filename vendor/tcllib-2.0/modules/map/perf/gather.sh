#!/usr/bin/bash
##
# Generate raw perf data ...
set -x

./sak.tcl critcl

./sak.tcl bench -format csv -match '*/critcl *' -o modules/map/perf/critcl.csv modules/map
./sak.tcl bench -format csv -match '*/tcl *'    -o modules/map/perf/tcl.csv    modules/map

rm -rf modules/tcllibc
rm -rf include

# Move differences from bench description into the interpreter path.

sed -i -s 's|/critcl | |'           modules/map/perf/critcl.csv
sed -i -s 's|/tclsh|/tclsh-critcl|' modules/map/perf/critcl.csv

sed -i -s 's|/tcl | |'              modules/map/perf/tcl.csv
sed -i -s 's|/tclsh|/tclsh-tcl|'    modules/map/perf/tcl.csv

# Fuse, raw times, and normalized using critcl as base (expected to be faster)

./sak.tcl bench/show -o modules/map/perf/compare.txt              modules/map/perf/critcl.csv modules/map/perf/tcl.csv
./sak.tcl bench/show -o modules/map/perf/compare.norm.txt -norm 1 modules/map/perf/critcl.csv modules/map/perf/tcl.csv

# Done
date
exit
