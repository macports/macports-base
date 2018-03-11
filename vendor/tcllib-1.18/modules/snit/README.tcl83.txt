#--------------------------------------------------------------------------
# README.tcl83.txt
#--------------------------------------------------------------------------
# Back-port of Snit to Tcl83
#--------------------------------------------------------------------------
# Copyright
#
# Copyright (c) 2005 Kenneth Green
# All rights reserved
#--------------------------------------------------------------------------
# This code is freely distributable, but is provided as-is with
# no warranty expressed or implied.
#--------------------------------------------------------------------------
# Acknowledgements
#   1) The changes described in this file are made to awesome 'snit' 
#      library as provided by William H. Duquette under the terms
#      defined in the associated 'license.txt'.
#--------------------------------------------------------------------------

Snit is pure-Tcl object and megawidget framework.  See snit.html
for full details.

It was written for Tcl/Tk 8.4 but a back-port to Tcl/Tk 8.3 has been
done by Kenneth Green (green.kenneth@gmail.com).

-----------------------------------------------------------------

The back-port to Tcl 83 passes 100% of the snit.test test cases.
It adds two files to the package, this README file plus the back-port
utility file: snit_tcl83_utils.tcl.

Very few changes were required to either snit.tcl or snit.test to
get them to run with Tcl/Tk 8.3. All changes in those files are
tagged with a '#kmg' comment.

-----------------------------------------------------------------
07-Jun-2005 kmg (Release 1.0.1)
    Port of first full snit release 1.0
    Passes 452/452 test cases in snit.test
    Known problems:
	1) In some cases that I have not been able to characterise, an instance 
           will be destroyed twice causing an error. If this happens, try wrapping
           your deletion of the instance in a catch.
	2) As a consequence of (1), one test case generates an error in its
           cleanup phase, even though the test itself passes OK


10-Feb-2005 kmg (Beta Release 0.95.2)
    Fixed bug in 'namespace' procedure in snit_tcl83_utils.tcl.
    Made it execute the underlying __namespace__ in the context
    of the caller's namespace.

28-Aug-2004 kmg (Beta Release 0.95.1)
    First trial release of the back-port to Tcl/Tk 8.3
    Snit will work fine on Tcl/Tk 8.4 but a few of the tests
    will have to have the changes commented out and the original
    code uncommented in order to pass.
