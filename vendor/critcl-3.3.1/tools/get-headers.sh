#!/bin/bash

src=$1
dst=$2

for header in \
    tclDecls.h tcl.h tclPlatDecls.h
do
    cp -v ${src}/generic/$header lib/critcl/critcl_c/$dst
done
