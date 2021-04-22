# -*- tcl -*- 
# -- $Id: reader_treeser.tcl,v 1.1 2005/09/28 04:51:22 andreas_kupries Exp $ ---
#
# PAGE plugin - reader - TREESER ~ Serialized TREE
#

# ### ### ### ######### ######### #########
## Imported API

# -----------------+--
# page_read        | Access to the input stream.
# page_read_done   |
# page_eof         |
# -----------------+--
# page_info        | Reporting to the user.
# page_warning     |
# page_error       |
# -----------------+--
# page_log_error   | Reporting of internals.
# page_log_warning |
# page_log_info    |
# -----------------+--

# ### ### ### ######### ######### #########
## Exported API

# -----------------+--
# page_rfeature    | Query for special plugin features page might wish to use.
# page_rtime       | Activate collection of timing statistics.
# page_rgettime    | Return the collected timing statistics.
# page_rlabel      | User readable label for the plugin.
# page_rhelp       | Doctools help text for plugin.
# page_roptions    | Options understood by plugin.
# page_rconfigure  | Option (re)configuration.
# page_rdata       | External access to processed input stream.
# page_rrun        | Process input stream per plugin configuration and hardwiring.
# -----------------+--

# ### ### ### ######### ######### #########
## Requisites

package require struct::tree ; # Data structure.

global usec
global timed
set    timed 0

# ### ### ### ######### ######### #########
## Implementation of exported API

proc page_rlabel {} {
    return {Serialized Tree}
}

proc page_rfeature {key} {
    return [string eq $key timeable]
}

proc page_rtime {} {
    global timed
    set    timed 1
    return
}

proc page_rgettime {} {
    global  usec
    return $usec
}

proc page_rhelp {} {
    return {}
}

proc page_roptions {} {
    return {}
}

proc page_rconfigure {option value} {
    return -code error "Cannot set value of unknown option \"$option\""
}

## proc page_rdata {} {}
## Created in 'Initialize'

proc page_rrun {} {
    global timed usec
    page_log_info "reader/treeser/run/parse"

    if {$timed} {
	set usec [lindex [time {
	    set data [page_read]
	}] 0] ; #{}
    } else {
	set data [page_read]
    }
    page_read_done

    # Reading and passing it on is trivial.
    # Here however we validate the we truly got
    # a sensible serialization.

    struct::tree ::tree
    ::tree deserialize $data
    ::tree destroy

    page_log_info "reader/treeser/run/ok"
    return $data
}

# ### ### ### ######### ######### #########
## Internal helper code.

# ### ### ### ######### ######### #########
## Initialization

package provide page::reader::treeser 0.1
