#!/bin/bash

gnuplot              svs/svs.gnuplot
ps2pdf -sPAGESIZE=a4 svs/svs.ps svs/svs.pdf
rm                   svs/svs.ps

echo See svs/svs.pdf
