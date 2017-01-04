# -*- tcl -*-

# This file holds the commands determining the files to install. They
# are used by the installer to actually perform the installation, and
# by 'sak' to get the per-module lists of relevant files. The
# different purposes are handled through the redefinition of the
# commands [xcopy] and [xcopyf] used by the commands here.

proc _null {args} {}

proc _tcl {module libdir} {
    global distribution
    xcopy \
	    [file join $distribution modules $module] \
	    [file join $libdir $module] \
	    0 *.tcl
    return
}

proc _tcr {module libdir} {
    global distribution
    xcopy \
	    [file join $distribution modules $module] \
	    [file join $libdir $module] \
	    1 *.tcl
    return
}

proc _rde {module libdir} {
    global distribution

    _tcl $module $libdir
    xcopy \
	    [file join $distribution modules $module rde_critcl] \
	    [file join $libdir $module rde_critcl] \
	    1
    return
}

proc _doc {module libdir} {
    global distribution

    _tcl $module $libdir
    xcopy \
	    [file join $distribution modules $module mpformats] \
	    [file join $libdir $module mpformats] \
	    1
    return
}

proc _msg {module libdir} {
    global distribution

    _tcl $module $libdir
    xcopy \
	    [file join $distribution modules $module msgs] \
	    [file join $libdir $module msgs] \
	    1
    return
}

proc _tex {module libdir} {
    global distribution

    _tcl $module $libdir
    xcopy \
	    [file join $distribution modules $module] \
	    [file join $libdir $module] \
	    0 *.tex
    return
}

proc _tci {module libdir} {
    global distribution

    _tcl $module $libdir
    xcopyfile [file join $distribution modules $module tclIndex] \
	    [file join $libdir $module]
    return
}

proc _trt {module libdir} {
    global distribution

    _tcr $module $libdir
    xcopy \
	    [file join $distribution modules $module] \
	    [file join $libdir $module] \
	    0 *.template
    return
}

proc _manfile {f format ext docdir} { return }
proc _man {module format ext docdir} { return }

proc _exa {module exadir} {
    global distribution
    xcopy \
	    [file join $distribution examples $module] \
	    [file join $exadir $module] \
	    1
    return
}

proc _exax {actual module exadir} {
    global distribution
    xcopy \
	    [file join $distribution examples $actual] \
	    [file join $exadir $module] \
	    1
    return
}
