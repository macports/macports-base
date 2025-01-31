# https://raymii.org/s/tutorials/GNUplot_tips_for_nice_looking_charts_from_a_CSV_file.html

set datafile separator ','

set key autotitle columnhead # use the first line as title

set ylabel "Microseconds" # label for the Y axis
set xlabel 'Unicodepoint' # label for the X axis

#set terminal pngcairo size 800,600 enhanced font 'Segoe UI,10' 
#set output 'wcswidth.png'

set terminal postscript enhanced color landscape 'Arial' 12

set output 'bench.ps'
set size ratio 0.71 # for the A4 ratio

plot 'bench.csv' using 1:2 with lines, \
     '' 	 using 1:3 with lines
