set datafile separator ','
set key autotitle columnhead # use the first line as title

set ylabel "microseconds" # label for the Y axis
set xlabel 'codepoints'   # label for the X axis

set terminal postscript enhanced color landscape 'Arial' 12
set output 'compare/compare.ps'
set size ratio 0.71 # for the A4 ratio

# Type response

plot 'i.2map/bench.csv'    using 1:2 with lines, \
     'i.map/bench.csv'     using 1:2 with lines, \
     'i.binary/bench.csv'  using 1:2 with lines, \
     'i.ternary/bench.csv' using 1:2 with lines, \
     'i.linear/bench.csv'  using 1:2 with lines

plot 'i.2map/bench.csv'    using 1:2 with lines, \
     'i.map/bench.csv'     using 1:2 with lines, \
     'i.ternary/bench.csv' using 1:2 with lines, \
     'i.binary/bench.csv'  using 1:2 with lines

plot 'i.2map/quartiles.csv'    using 1:2 with lines, \
     'i.map/quartiles.csv'     using 1:2 with lines, \
     'i.binary/quartiles.csv'  using 1:2 with lines, \
     'i.ternary/quartiles.csv' using 1:2 with lines, \
     'i.linear/quartiles.csv'  using 1:2 with lines

plot 'i.2map/quartiles.csv'    using 1:2 with lines, \
     'i.map/quartiles.csv'     using 1:2 with lines, \
     'i.binary/quartiles.csv'  using 1:2 with lines, \
     'i.ternary/quartiles.csv' using 1:2 with lines

# Width response

plot 'i.2map/bench.csv'    using 1:3 with lines, \
     'i.map/bench.csv'     using 1:3 with lines, \
     'i.binary/bench.csv'  using 1:3 with lines, \
     'i.ternary/bench.csv' using 1:3 with lines, \
     'i.linear/bench.csv'  using 1:3 with lines

plot 'i.2map/bench.csv'    using 1:3 with lines, \
     'i.map/bench.csv'     using 1:3 with lines, \
     'i.ternary/bench.csv' using 1:3 with lines, \
     'i.binary/bench.csv'  using 1:3 with lines

plot 'i.2map/quartiles.csv'    using 1:3 with lines, \
     'i.map/quartiles.csv'     using 1:3 with lines, \
     'i.binary/quartiles.csv'  using 1:3 with lines, \
     'i.ternary/quartiles.csv' using 1:3 with lines, \
     'i.linear/quartiles.csv'  using 1:3 with lines

plot 'i.2map/quartiles.csv'    using 1:3 with lines, \
     'i.map/quartiles.csv'     using 1:3 with lines, \
     'i.binary/quartiles.csv'  using 1:3 with lines, \
     'i.ternary/quartiles.csv' using 1:3 with lines

# ternay vs binary only

plot 'i.ternary/bench.csv' using 1:2 with lines, \
     'i.binary/bench.csv'  using 1:2 with lines

plot 'i.ternary/quartiles.csv' using 1:2 with lines, \
     'i.binary/quartiles.csv'  using 1:2 with lines

plot 'i.ternary/bench.csv' using 1:3 with lines, \
     'i.binary/bench.csv'  using 1:3 with lines

plot 'i.ternary/quartiles.csv' using 1:3 with lines, \
     'i.binary/quartiles.csv'  using 1:3 with lines
