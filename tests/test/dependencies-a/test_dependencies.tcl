package require tcltest 2
namespace import tcltest::*

global datadir

source ../library.tcl

set path [pwd]

load_variables
cd ../..
set_dir
port_index
cd $path
port_clean
port_run
