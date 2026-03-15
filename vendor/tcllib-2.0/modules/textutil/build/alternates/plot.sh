#!/bin/bash

# Per implementation, basic plot
bench_plot() {
    base="i.${1}"
    cp "${base}/bench.csv" bench.csv    
    gnuplot bench/bench.gnuplot
    rm bench.csv
    ps2pdf -sPAGESIZE=a4 bench.ps bench.pdf
    rm bench.ps
    mv bench.pdf "${base}/bench.pdf"
    echo See "${base}/bench.pdf"
}

bench_plot map
bench_plot binary
bench_plot ternary
bench_plot 2map
bench_plot linear

# speed versus size plot
./svs.sh

# various overall comparisons, quartiles
./compare.sh

exit
