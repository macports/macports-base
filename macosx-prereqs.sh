#!/bin/sh
#
# Check for prerequisite packages on MacOSX.

RVAL=0
R_DIR=/Library/Receipts
NEED="BSD BSDSDK DeveloperTools"
WANT="X11User X11SDK"

for i in $NEED; do
	if [ ! -d "${R_DIR}/${i}.pkg" ]; then
		echo "Error: Missing Pkg: You need to install the ${i} package before you can install darwinports."
		RVAL=1
	fi
done

for i in $WANT; do
	if [ ! -d "${R_DIR}/${i}.pkg" ]; then
		echo "Warning: You may wish to install the ${i} package to have the best possible experience with darwinports."
	fi
done

exit $RVAL
