# callback.tcl -
#
# C support package for the management of callbacks into Tcl.
#
# __Note__, this package does not expose anything at Tcl level.  It
# only provides stubs (i.e. functions) and data structures providing
# C-level callback managers.

package provide critcl::callback 1.1

package require critcl 3.2
critcl::buildrequirement {
    package require critcl::cutil ;# assertions, allocation support, tracing
}

if {![critcl::compiling]} {
    error "Unable to build `critcl::callback`, no proper compiler found."
}

# # ## ### ##### ######## #############
## Build configuration
# (1) Assertions, and tracing
# (2) Debugging symbols, memory tracking

critcl::cutil::assertions off
critcl::cutil::tracer     off

#critcl::debug symbols

#Activate when in need of memory debugging - Valgrind is an alternative
#critcl::debug symbols memory

critcl::config lines 1
critcl::config trace 0

# # ## ### ##### ######## #############
## Administrivia

critcl::license \
    {Andreas Kupries} \
    {Under a BSD license.}

critcl::summary \
    {Critcl utility package providing functions and structures to manage callbacks into Tcl, from C}

critcl::description \
    {Part of Critcl}

critcl::subject critcl callbacks {management of callbacks}
critcl::subject {Tcl callbacks from C}

# # ## ### ##### ######## #############
## Implementation.

critcl::cutil::alloc

# # ## ### ##### ######## #############

critcl::cheaders c/*.h
critcl::csources c/*.c

# Stubs definitions.

critcl::api header c/callback.h

# Create a new callback instance with prefix objc/objv and space for
# `nargs` arguments. The callback keeps the objv elements as is and
# signal this by incrementing their reference counts. The callback
# will be run in the provided interpreter, at the global level and
# namespace.

critcl::api function critcl_callback_p critcl_callback_new {
    Tcl_Interp* interp
    Tcl_Size    objc
    Tcl_Obj**   objv
    Tcl_Size    nargs
}

# Modify the specified callback by placing the argument into the first
# free argument slot. This extends the prefix part of the callback,
# and reduces the argument part, by one.

critcl::api function void critcl_callback_extend {
    critcl_callback_p callback
    Tcl_Obj*          argument
}

# Release all memory associated with the callback instance. For the
# objv elements saved during construction (see above) this is signaled
# by decrementing their reference counts.

critcl::api function void critcl_callback_destroy {
    critcl_callback_p callback
}

# Invoke the callback using the objc/objv elements as the arguments.
# The operation will panic or crash if more arguments are provided
# than the callback has space for. See the `nargs` parameter of the
# constructor function above. Less arguments then constructed for
# however are ok.

critcl::api function int critcl_callback_invoke {
    critcl_callback_p callback
    Tcl_Size          objc
    Tcl_Obj**         objv
}

##
return
