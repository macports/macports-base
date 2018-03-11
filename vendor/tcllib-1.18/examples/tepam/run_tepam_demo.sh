#!/bin/sh

# Run the TEPAM demo with the local tcllib/tepam, and not with the one installed on the system

TCLLIBPATH="../../modules"
export TCLLIBPATH 

wish tepam_demo.tcl &
