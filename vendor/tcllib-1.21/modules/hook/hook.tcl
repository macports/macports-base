# hook.tcl
#
#       This file implements the hook(n) Subject/Observer
#       callback mechanism.  Any number of observers can register for
#       a particular hook from a particular subject; when the
#       subject calls the hook, all observers are called.
#
# Copyright (C) 2010 by Will Duquette
#
# See the file "license.terms" for information on usage and
# redistribution of this file, and for a DISCLAIMER OF ALL
# WARRANTIES.

namespace eval hook {
    namespace export bind call cget configure forget
    namespace ensemble create

    # Subject Dictionary:
    #
    # Dictionary subject -> hook -> observer -> binding

    variable sdict [dict create]

    # Observer Dictionary:
    #
    # Dictionary observer -> subject -> hook -> 1
    #
    # The "1" is so that the hook name is a key, and can be
    # cleared using [dict unset $o $s $h]

    variable odict [dict create]

    # Observer counter
    #
    # Used to auto-generate observer names in [hook bind].

    variable observerCounter 0

    # Configuration options
    #
    # -errorcommand  Handles errors in hook bindings.
    # -tracecommand  Trace called hooks.

    variable options
    array set options {
        -errorcommand {}
        -tracecommand {}
    }
}


# hook::bind --
#
#       By default, binds an observer to a subject's hook.
#       Alternatively, bind can delete or query a binding, or query a
#       number of bindings.
#
# Arguments:
#       subject   (optional) The name of the entity that owns the hook.
#                 It will usually be a fully-qualified command
#                 name, but "virtual" subjects are also allowed.
#
#       hook      (optional) The name of the hook.  By convention,
#                 hook names are enclosed in angle brackets and contain
#                 no whitespace; however, any non-empty string is allowed.
#
#       observer  (optional) The name of the entity observing the hook.
#                 It will usually be a fully-qualified command name,
#                 but "virtual" observers are also allowed.
#
#                 If observer is the empty string, an observer name
#                 of the form "::hook::ob<num>" will be generated.
#
#       binding   (optional) The binding proper, a command prefix to which
#                 the hook's arguments will be appended.
#
# Results:
#       If called with no arguments, returns a list of the names of the
#       subjects to which observers are bound.
#
#       If called with just a subject name, returns a list of the names
#       of the subject's hooks to which bindings are bound.
#
#       If called with just a subject name and a hook name, returns a
#       list of the names of the observers bound to that subject and hook.
#
#       If called with a subject name, hook name, and observer name,
#       returns the associated binding, or the empty string if none.
#
#       If called with all four arguments, it either adds or deletes
#       a binding.  If the binding is the empty string, any existing
#       binding is deleted and the empty string is returned.
#       Otherwise the binding is saved, and the observer name is
#       returned.  The observer will be automatically
#       generated if the empty string is given.

proc hook::bind {args} {
    variable sdict
    variable odict
    variable observerCounter

    # FIRST, there should be no more than four args.
    set argc [llength $args]

    if {$argc > 4} {
        return -code error "wrong # args: should be \"hook bind ?subject? ?hook? ?observer? ?binding?\""
    }

    lassign $args subject hook observer binding

    # NEXT, Add, update, or delete a binding.
    if {$argc == 4} {
        if {$binding ne ""} {
            # FIRST, auto-generate an observer, if need be.  Note that
            # with bignums there's no chance of running out of valid
            # observer IDs.
            if {$observer eq ""} {
                set observer [namespace current]::ob[incr observerCounter]
            }

            # NEXT, add or update the binding
            dict set sdict $subject $hook $observer $binding
            dict set odict $observer $subject $hook 1

            # NEXT, return the observer.
            return $observer
        } else {
            if {[dict exists $sdict $subject $hook $observer]} {
                dict unset sdict $subject $hook $observer
            }
            if {[dict exists $odict $observer $subject $hook]} {
                dict unset odict $observer $subject $hook
            }
        }

        return
    }

    # NEXT, Query a binding
    if {$argc == 3} {
        if {[dict exists $sdict $subject $hook $observer]} {
            return [dict get $sdict $subject $hook $observer]
        } else {
            return {}
        }
    }

    # NEXT, Query the observers bound to a subject and hook.
    if {$argc == 2} {
        if {[dict exists $sdict $subject $hook]} {
            return [dict keys [dict get $sdict $subject $hook]]
        } else {
            return {}
        }
    }

    # NEXT, query the bound hooks for a given subject.
    if {$argc == 1} {
        if {[dict exists $sdict $subject]} {
            return [dict keys [dict get $sdict $subject]]
        } else {
            return {}
        }
    }

    # FINALLY, query the subjects with active bindings.
    return [dict keys $sdict]
}


# hook::forget --
#
#       Forget all bindings in which a named entity appears as either
#       subject or observer.  No error is raised if the named entity
#       appears in no bindings at all.
#
# Arguments:
#       object    The name of a subject, an observer, or both.
#
# Results:
#       Returns the empty string.

proc hook::forget {object} {
    variable sdict
    variable odict

    # FIRST, get rid of any odict entries for which this object
    # is the subject.
    if {[dict exists $sdict $object]} {
        dict for {hook dict_o} [dict get $sdict $object] {
            dict for {observer binding} $dict_o {
                dict unset odict $observer $object $hook
            }
        }
    }


    # NEXT, get rid of any sdict entries for which this object is
    # the observer.
    if {[dict exists $odict $object]} {
        dict for {subject hdict} [dict get $odict $object] {
            dict for {hook dummy} $hdict {
                dict unset sdict $subject $hook $object
            }
        }
    }


    # NEXT, get rid of this object from sdict as subject.
    dict unset sdict $object

    # NEXT, get rid of this object form odict as observers.
    dict unset odict $object


    return
}

# hook::call --
#
#       A subject calls a hook.  Bindings are called for all bound
#       observers.  There is no guarantee of the order in which bindings
#       will be called.  All bindings are called before the call returns.
#       Note that modules should document the hooks they call, including
#       details of any arguments associated with each hook.
#
# Arguments:
#       subject     The subject sending the hook
#       hook        The name of the hook being sent
#       args        (optional) any arguments for this subject and hook.
#
# Results:
#       The bindings are called in no particular order; the args are
#       appended to each binding.  Returns the empty string.
#
#       If -errorcommand is defined, errors in bindings are handled
#       by the specified command.  It is called with three arguments:
#       a list of the subject, hook, args, and observer, the error result,
#       and the return options dictionary.
#
#       When the -tracecommand is set, it is called with four arguments:
#       the subject, the hook, a list of the hook arguments, and a
#       list of the receiving observers.

proc hook::call {subject hook args} {
    variable sdict
    variable options

    # FIRST, If there are no observers we're done.
    if {[dict exists $sdict $subject $hook]} {
        set observers [dict keys [dict get $sdict $subject $hook]]
    } else {
        set observers [list]
    }

    # NEXT, for each observer, retrieve the binding (if it
    # still exists) and execute it.  Keep track of the observers
    # for which the hook was actually called.
    set called [list]

    foreach observer $observers {
        # FIRST, skip bindings that no longer exist.
        if {![dict exists $sdict $subject $hook $observer]} {
            continue
        }

        set binding [dict get $sdict $subject $hook $observer]

        # NEXT, remember that we called a binding for this observer.
        lappend called $observer

        if {$options(-errorcommand) eq ""} {
            uplevel #0 [list {*}$binding {*}$args]
        } elseif {[catch {
            uplevel #0 [list {*}$binding {*}$args]
        } result opts]} {
            uplevel #0 \
                [list {*}$options(-errorcommand) \
                     [list $subject $hook $args $observer] \
                     $result                               \
                     $opts]
        }
    }

    if {$options(-tracecommand) ne ""} {
        {*}$options(-tracecommand) $subject $hook $args $called
    }

    return
}

# hook::cget --
#
#       Returns the value of a hook configuration option.
#
# Arguments:
#       option    The name of the option
#
# Results:
#       Returns the option's value.  Throws an error if the
#       option name is invalid.

proc hook::cget {option} {
    variable options

    if {$option ni [array names options]} {
        return -code error "unknown option \"$option\""
    }

    return $options($option)
}


# hook::configure --
#
#       Sets the value of one or more hook configuration options.
#
# Arguments:
#       args   A list of option names and their values
#
# Results:
#       Saves the option values.  Throws an error for unknown options
#       and invalid values.  No option values are changed on error.

proc hook::configure {args} {
    variable options

    # FIRST, validate the options
    set argc [llength $args]
    set i 0

    while {$i < $argc} {
        # FIRST, make sure it's a known option.
        set option [lindex $args [incr i]-1]

        if {$option ni [array names options]} {
            return -code error "unknown option \"$option\""
        }

        # NEXT, make sure a value is specified.
        if {$i == $argc} {
            return -code error "value for \"$option\" missing"
        }

        # NEXT, skip the value
        incr i
    }

    # NEXT, save the values
    array set options $args

    return
}

# ---------------------------------------------------------------
# Ready

package provide hook 0.2
