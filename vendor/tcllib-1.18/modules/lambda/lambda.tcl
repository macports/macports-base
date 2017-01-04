# # ## ### ##### ######## ############# ####################
## -*- tcl -*-
## (C) 2011 Andreas Kupries, BSD licensed.

# Two convenience commands to make the writing of anonymous
# procedures, i.e. lambdas more proc-like. Instead of, for example, to
# write
#
#      set f {::apply {{x} { .... }}}
#
# with its deep nesting of braces, or (if we wish to curry (*))
#
#      set f [list ::apply {{x y} { .... }} $valueforx]
#
# with a list command to insert the arguments, just write
#
#      set f [lambda {x} { .... }]
# and
#      set f [lambda {x y} { .... } $valueforx]
#
# (*) Pre-supply arguments to the anon proc, making the lambda a
#     partial application.

# # ## ### ##### ######## ############# ####################
## Requisites

package require Tcl 8.5

# # ## ### ##### ######## ############# #####################
## Public API implementation

proc lambda {arguments body args} {
    return [list ::apply [list $arguments $body] {*}$args]
}

proc lambda@ {ns arguments body args} {
    return [list ::apply [list $arguments $body $ns] {*}$args]
}

# # ## ### ##### ######## ############# ####################
## Ready
package provide lambda 1

