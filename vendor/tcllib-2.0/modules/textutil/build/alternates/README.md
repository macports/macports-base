# Performance Research

This directory contains all the files used during research into the performance of various alternate
implementations for the wcswidth commands.

## Algorithms

Five different algorithms are evaluated.

|Algorithm	|The result is determined ...							|
|---		|---										|
|`map`		|... by using the numeric codepoint to index into a __very large__ list		|
|`binary`	|... by a binary tree of nested `if`-checks					|
|`ternary`	|... by a binary tree of nested ternary expressions				|
|`2map`		|... through direct indexing in two lists, using redundancies in the results	|
|`linear`	|... through a linear series of `if`-checks					|

The `linear` algorithm is the easiest to generate, it can be done in a single pass over the database
file. All others need some internal data structures and phases to convert the information in various
ways before emitting code.

## Chosen algorithm

The chosen algorithm is `binary`.

Of the five algorithms looked at `linear` is the slowest by far, with the second slowest (`2map`)
already about 25 times faster. The fastest algorithm, `map` is even about 46 times faster. That
speed unfortunately comes with a factor 126 size overhead, i.e. 2 orders of magnitude. Because of
this `map` is removed from consideration too.

Of the three left `2map` is not only the slowest, it also has a larger size overhead than the other
two. The performance was actually a surprise. Initial expectation was that its two list indexing
ops, plus the math for it, would be faster than running through the tree of conditionals used by
`binary` and `ternary`.

For `binary` and `ternay` the size of the code is actually more strongly influenced by the chosen
formatting than the Tcl commands themselves. I.e. a good chunk of the overhead comes from formatting
the Tcl code for readability. Forsaking that brings both down to the size of `linear`.

Because of that code size is ignored now, and `binary` is chosen for speed. It is a tick faster than
`ternary`. The reason for that is currently not known.

## Detailed information

### General speed, code size

Notes:

  - The algorithms are ordered by time, from fastest down to slowest.

  - The overhead and gain values are computed relative to the base algorithm, `linear`. The
    incremental (`*/I`) values are computed relative to the algorithm in the row below (or itself,
    for the bottom row).

  - Time unit is seconds.

  - Due to the benchmarking repeating each codepoint a thousand times the `Points/s` is computed as
    `1114112*1000/(time)`.

|Algorithm	|Code Size	|Overhead	|Overhead/I	|Time		|Points/s	|Gain	|Gain/I	|
|---		|---:		|---:		|---:		|---:		|---:		|---:	|---:	|
|map		|4492047	|126.00		|104.48		|851.58		|1308295.80	|48.11	|1.53	|
|binary		|42994		|1.21		|1.30		|1304.00	|854379.71	|31.42	|1.07	|
|ternary	|33037		|0.93		|0.50		|1396.33	|797886.46	|29.34	|1.11	|
|2map		|66463		|1.86		|1.86		|1554.56	|716674.91	|26.36	|26.36	|
|linear		|35651		|1.00		|1.00		|40972.78	|27191.51	|1.00	|1.00	|

### Statistics.

Five values are shown, per algorithm and command (type information, width information).

  - Fastest response, minimum time

  - Slowest response, maximum time

  - 50th quartile, median response, time in which half the points are handled.

  - 90th quartile, time in which 90% of the points are handled.

  - 99th quartile, time in which 99% of the points are handled.

Note

  - The time unit is microseconds.
  
  - For all algorithms the 99th quartile is well below the maximum response time. The maximum
    response times are likely outliers caused by external factors influencing benchmark operation.
    Looking at the visualizations across the range indicate the same

|Algorithm	|Type Min	|Max	|50%	|90%	|99%	|Width Min	|Max	|50%	|90%	|99%	|
|---		|---:		|---:	|---:	|---:	|---:	|---:		|---:	|---:	|---:	|---:	|
|map		|0.34		|1.05	|0.35	|0.36	|0.38	|0.35		|1.09	|0.35	|0.36	|0.39	|
|binary		|0.52		|2.15	|0.59	|0.61	|0.64	|0.49		|1.89	|0.51	|0.54	|0.57	|
|ternary	|0.58		|2.13	|0.66	|0.69	|0.71	|0.5		|1.72	|0.52	|0.56	|0.6	|
|2map		|0.63		|2.37	|0.66	|0.67	|0.78	|0.64		|2.35	|0.66	|0.67	|0.78	|
|linear		|0.38		|39.21	|23.8	|24.14	|24.59	|0.41		|22.25	|13.56	|13.72	|13.97	|

## Directory Structure

Notes:

  - The `.csv` files are stored `xz` compressed, due to their large size (20M).
  
  - The `.pdf` files are not in the repository. Use `plot.sh` to generate them from the .csv
    files. Decompress the .csz.xz files before doing so.

|Pattern		|Notes							|
|---			|---							|
|regen.sh		|Regenerate all implementations				|
|plot.sh		|Generate the .pdf files from the other data		|
|			|							|
|bench.sh		|Benchmark all implementations				|
|bench/bench.gnuplot	|Plot configuration to visualize a bench result		|
|bench/bench.tcl	|Benchmark a specific implementation			|
|bench/stats.tcl	|Compute statistics from bench results			|
|bench/stats-tables.tcl	|Compute the tables shown in this README.		|
|bench/quartiles.tcl	|Compute response time quartiles			|
|			|							|
|check.sh		|Check implementations for result mismatches		|
|check/check.tcl	|Check implementations for result mismatches		|
|			|							|
|svs.sh			|Generate size/speed plots				|
|svs/all.csv		|Size/speed for all implementations - Manual		|
|svs/without-map.csv	|As above, with `map` removed due its very large size	|
|svs/svs.gnuplot	|Plot configuration					|
|svs/svs.pdf(.xz)	|Resulting plot						|
|			|							|
|compare.sh		|Various comparisons, quartile plots, etc.		|
|compare/compare.gnuplot|Plot configuration					|
|compare/compare.pdf(.xz)|Resulting plot					|
|			|							|
|(alg)/build.tcl	|Generator script					|
|(alg)/wcswidth.tcl	|Generated implementation				|
|(alg)/bench.csv(.xz)	|Benchmarking result					|
|(alg)/bench-stats.csv	|Result statistics					|
|(alg)/bench.pdf(.xz)	|Visualized results					|
|(alg)/quartiles.csv	|Results from `bench/quartiles.tcl`			|
