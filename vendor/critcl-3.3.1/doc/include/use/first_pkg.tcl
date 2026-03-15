# -*- tcl -*-
# Critcl support, absolutely necessary.
package require critcl

# Bail out early if the compile environment is not suitable.
if {![critcl::compiling]} {
    error "Unable to build project, no proper compiler found."
}

# Information for the teapot.txt meta data file put into a generated package.
# Free form strings.
critcl::license {Andreas Kupries} {Under a BSD license}

critcl::summary {The first CriTcl-based package}

critcl::description {
    This package is the first example of a CriTcl-based package. It contains all the
    necessary and conventionally useful pieces.
}

critcl::subject example {critcl package}
critcl::subject {basic critcl}

# Minimal Tcl version the package should load into.
critcl::tcl 8.6

# ## #### ######### ################ #########################
## A hello world, directly printed to stdout. Bypasses Tcl's channel system.

critcl::cproc hello {} void {
    printf("hello world\n");
}

# ## #### ######### ################ #########################

# Forcing compilation, link, and loading now.
critcl::msg -nonewline { Building ...}
if {![critcl::load]} {
    error "Building and loading the project failed."
}

# Name and version the package. Just like for every kind of Tcl package.
package provide critcl-example 1
