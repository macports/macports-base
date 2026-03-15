#!/bin/bash

gnuplot              compare/compare.gnuplot
ps2pdf -sPAGESIZE=a4 compare/compare.ps compare/compare.pdf
rm                   compare/compare.ps

echo See compare/compare.pdf
