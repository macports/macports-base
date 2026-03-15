#!/bin/bash

bench_implementation() {
    base="i.${1}"

    echo Benchmarking $1 ...

    code="${base}/wcswidth.tcl"
    rcsv="${base}/bench.csv"
    stat="${base}/bench-stats.csv"

    size=...

    time tclsh bench/bench.tcl  "${code}" > "${rcsv}"
    tclsh      bench/stats.tcl $base $size "${rcsv}" > "${stat}"

    cp "${rcsv}" bench.csv
    
    gnuplot bench/bench.gnuplot
    rm bench.csv
    ps2pdf -sPAGESIZE=a4 bench.ps bench.pdf
    rm bench.ps
    mv bench.pdf "${base}/bench.pdf"

    echo /Done
}

(
    bench_implementation map
    bench_implementation binary
    bench_implementation ternary
    bench_implementation 2map
    bench_implementation linear
) | tee bench.log
