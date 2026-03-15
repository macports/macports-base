set datafile separator ','
set key autotitle columnhead # use the first line as title

set ylabel "points/s" # label for the Y axis
set xlabel 'bytes'    # label for the X axis

#set terminal pngcairo size 800,600 enhanced font 'Segoe UI,10' 
#set output 'cs-all.png'

set terminal postscript enhanced color landscape 'Arial' 12

set output 'svs/svs.ps'

set size ratio 0.71 # for the A4 ratio

plot 'svs/all.csv'         using 2:3 with lines
plot 'svs/without-map.csv' using 2:3 with lines
