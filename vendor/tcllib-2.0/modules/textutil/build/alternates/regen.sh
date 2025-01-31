#!/bin/bash

generate_implementation() {
    echo Regen $1
    
    base="i.${1}"
    cp ../EastAsianWidth.txt $base
    tclsh $base/build.tcl
    rm $base/EastAsianWidth.txt
    mv wcswidth.tcl $base/
}

#generate_implementation map
#generate_implementation binary
#generate_implementation ternary
#generate_implementation 2map
#generate_implementation linear
