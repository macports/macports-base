# -*- tcl -*-
# ### ### ### ######### ######### #########

## This package provides custom plugin management specific to PAGE. It
## is built on top of the generic plugin management framework (See
## ---> pluginmgr).

# ### ### ### ######### ######### #########
## Requisites

package require fileutil
package require pluginmgr           ; # Generic plugin management framework

namespace eval ::page::pluginmgr {}

# ### ### ### ######### ######### #########
## API (Public, exported)

proc ::page::pluginmgr::reportvia {cmd} {
    variable reportcmd $cmd
    return
}

proc ::page::pluginmgr::log {cmd} {
    variable reader
    variable writer
    variable transforms

    set     iplist {}
    lappend iplist [$reader interpreter]
    lappend iplist [$writer interpreter]
    foreach t $transforms {
	lappend iplist [$t interpreter]
    }

    if {$cmd eq ""} {
	# No logging. Disable with empty command,
	# to allow the system to completely remove
	# them from the bytecode (= No execution
	# overhead).

	foreach ip $iplist {
	    $ip eval [list proc page_log_error   args {}]
	    $ip eval [list proc page_log_warning args {}]
	    $ip eval [list proc page_log_info    args {}]
	}
    } else {
	# Activate logging. Make the commands in
	# the interpreters aliases to us.

	foreach ip $iplist {
	    interp alias $ip page_log_error   {} ${cmd}::error
	    interp alias $ip page_log_warning {} ${cmd}::warning
	    interp alias $ip page_log_info    {} ${cmd}::info
	}
    }
    return
}

proc ::page::pluginmgr::reader {name} {
    variable reader

    $reader load $name
    return [$reader do page_roptions]
}

proc ::page::pluginmgr::rconfigure {dict} {
    variable reader
    foreach {k v} $dict {
	$reader do page_rconfigure $k $v
    }
    return
}

proc ::page::pluginmgr::rtimeable {} {
    variable reader
    return [$reader do page_rfeature timeable]
}

proc ::page::pluginmgr::rtime {} {
    variable reader
    $reader do page_rtime
    return
}

proc ::page::pluginmgr::rgettime {} {
    variable reader
    return [$reader do page_rgettime]
}

proc ::page::pluginmgr::rhelp {} {
    variable reader
    return [$reader do page_rhelp]
}

proc ::page::pluginmgr::rlabel {} {
    variable reader
    return [$reader do page_rlabel]
}

proc ::page::pluginmgr::read {read eof {complete {}}} {
    variable reader

    #interp alias $ip page_read {} {*}$read
    #interp alias $ip page_eof  {} {*}$eof

    set ip [$reader interpreter]
    eval [linsert $read 0 interp alias $ip page_read {}]
    eval [linsert $eof  0 interp alias $ip page_eof  {}]

    if {![llength $complete]} {
	interp alias $ip page_read_done {} ::page::pluginmgr::Nop
    } else {
	eval [linsert $complete  0 interp alias $ip page_read_done  {}]
    }

    return [$reader do page_rrun]
}

proc ::page::pluginmgr::writer {name} {
    variable writer

    $writer load $name
    return [$writer do page_woptions]
}

proc ::page::pluginmgr::wconfigure {dict} {
    variable writer
    foreach {k v} $dict {
	$writer do page_wconfigure $k $v
    }
    return
}

proc ::page::pluginmgr::wtimeable {} {
    variable writer
    return [$writer do page_wfeature timeable]
}

proc ::page::pluginmgr::wtime {} {
    variable writer
    $writer do page_wtime
    return
}

proc ::page::pluginmgr::wgettime {} {
    variable writer
    return [$writer do page_wgettime]
}

proc ::page::pluginmgr::whelp {} {
    variable writer
    return [$writer do page_whelp]
}

proc ::page::pluginmgr::wlabel {} {
    variable writer
    return [$writer do page_wlabel]
}

proc ::page::pluginmgr::write {chan data} {
    variable writer

    $writer do page_wrun $chan $data
    return
}

proc ::page::pluginmgr::transform {name} {
    variable transform
    variable transforms

    $transform load $name

    set id [llength $transforms]
    set opt [$transform do page_toptions]
    lappend transforms [$transform clone]

    return [list $id $opt]
}

proc ::page::pluginmgr::tconfigure {id dict} {
    variable transforms

    set t [lindex $transforms $id]

    foreach {k v} $dict {
	$t do page_tconfigure $k $v
    }
    return
}

proc ::page::pluginmgr::ttimeable {id} {
    variable transforms
    set t [lindex $transforms $id]
    return [$t do page_tfeature timeable]
}

proc ::page::pluginmgr::ttime {id} {
    variable transforms
    set t [lindex $transforms $id]
    $t do page_ttime
    return
}

proc ::page::pluginmgr::tgettime {id} {
    variable transforms
    set t [lindex $transforms $id]
    return [$t do page_tgettime]
}

proc ::page::pluginmgr::thelp {id} {
    variable transforms
    set t [lindex $transforms $id]
    return [$t do page_thelp]
}

proc ::page::pluginmgr::tlabel {id} {
    variable transforms
    set t [lindex $transforms $id]
    return [$t do page_tlabel]
}

proc ::page::pluginmgr::transform_do {id data} {
    variable transforms
    variable reader

    set t [lindex $transforms $id]

    return [$t do page_trun $data]
}

proc ::page::pluginmgr::configuration {name} {
    variable config

    if {[file exists $name]} {
	# Try as plugin first. On failure read it as list of options,
	# separated by spaces and tabs, and possibly quoted with
	# quotes and double-quotes.

	if {[catch {$config load $name}]} {
	    set ch      [open $name r]
	    set options [::read $ch]
	    close $ch

	    set def {}
	    while {[string length $options]} {
		if {[regsub "^\[ \t\n\]+" $options {} options]} {
		    # Skip whitespace
		    continue
		}
		if {[regexp -indices {^'(([^']|(''))*)'} \
			$options -> word]} {
		    foreach {__ end} $word break
		    lappend def [string map {'' '} [string range $options 1 $end]]
		    set options [string range $options [incr end 2] end]
		} elseif {[regexp -indices {^"(([^"]|(""))*)"} \
			$options -> word]} {
		    foreach {__ end} $word break
		    lappend def [string map {{""} {"}} [string range $options 1 $end]]
		    set options [string range $options [incr end 2] end]
		} elseif {[regexp -indices "^(\[^ \t\n\]+)" \
			$options -> word]} {
		    foreach {__ end} $word break
		    lappend def [string range $options 0 $end]
		    set options [string range $options [incr end] end]
		}
	    }
	    return $def
	}
    } else {
	$config load $name
    }
    set def [$config do page_cdefinition]
    $config unload
    return $def
}

proc ::page::pluginmgr::report {level text {from {}} {to {}}} {
    variable replevel
    variable reportcmd
    uplevel #0 [linsert $reportcmd end $replevel($level) $text $from $to]
    return
}

# ### ### ### ######### ######### #########
## Internals

## Data structures
##
## - reader    | Instances of pluginmgr configured for input,
## - transform | transformational, and output plugins. The
## - writer    | manager for transforms is actually a template
##             | from which the actual instances are cloned.

## - reportcmd | Callback for reporting of input error and warnings.
## - replevel  | Mapping from chosen level to the right-padded text
##             | to use.

namespace eval ::page::pluginmgr {
    variable  replevel
    array set replevel {
	info    {info   }
	warning {warning}
	error   {error  }
    }
}

proc ::page::pluginmgr::Initialize {} {
    InitializeReporting
    InitializeConfig
    InitializeReader
    InitializeTransform
    InitializeWriter
    return
}

proc ::page::pluginmgr::InitializeReader {} {
    variable commands
    variable reader_api
    variable reader [pluginmgr RD \
	    -setup   ::page::pluginmgr::InitializeReaderIp \
	    -pattern page::reader::* \
	    -api     $reader_api \
	    -cmdip   {} \
	    -cmds    $commands]

    # The page_log_* commands are set later, when it is known if
    # logging is active or not, as their implementation depends on
    # this.

    pluginmgr::paths $reader page::reader
    return
}

proc ::page::pluginmgr::InitializeReaderIp {p ip} {
    interp eval $ip {
	# @sak notprovided page::plugin
	# @sak notprovided page::plugin::reader
	package provide page::plugin         1.0
	package provide page::plugin::reader 1.0
    }
    interp alias $ip puts  {} puts
    interp alias $ip open  {} ::page::pluginmgr::AliasOpen $ip
    interp alias $ip write {} ::page::pluginmgr::WriteFile $ip
    return
}

proc ::page::pluginmgr::InitializeWriter {} {
    variable commands
    variable writer_api
    variable writer [pluginmgr WR \
	    -setup   ::page::pluginmgr::InitializeWriterIp \
	    -pattern page::writer::* \
	    -api     $writer_api \
	    -cmdip   {} \
	    -cmds    $commands]

    # The page_log_* commands are set later, when it is known if
    # logging is active or not, as their implementation depends on
    # this.

    pluginmgr::paths $writer page::writer
    return
}

proc ::page::pluginmgr::InitializeWriterIp {p ip} {
    interp eval $ip {
	# @sak notprovided page::plugin
	# @sak notprovided page::plugin::writer
	package provide page::plugin         1.0
	package provide page::plugin::writer 1.0
    }
    interp alias $ip puts  {} puts
    interp alias $ip open  {} ::page::pluginmgr::AliasOpen $ip
    interp alias $ip write {} ::page::pluginmgr::WriteFile $ip
    return
}

proc ::page::pluginmgr::InitializeTransform {} {
    variable transforms {}
    variable commands
    variable transform_api
    variable transform [pluginmgr TR \
	    -setup   ::page::pluginmgr::InitializeTransformIp \
	    -pattern page::transform::* \
	    -api     $transform_api \
	    -cmdip   {} \
	    -cmds    $commands]

    # The page_log_* commands are set later, when it is known if
    # logging is active or not, as their implementation depends on
    # this.

    pluginmgr::paths $transform page::transform
    return
}

proc ::page::pluginmgr::InitializeTransformIp {p ip} {
    interp eval $ip {
	# @sak notprovided page::plugin
	# @sak notprovided page::plugin::transform
	package provide page::plugin            1.0
	package provide page::plugin::transform 1.0
    }
    interp alias $ip puts  {} puts
    interp alias $ip open  {} ::page::pluginmgr::AliasOpen $ip
    interp alias $ip write {} ::page::pluginmgr::WriteFile $ip
    return
}

proc ::page::pluginmgr::InitializeConfig {} {
    variable config [pluginmgr CO \
	    -pattern page::config::* \
	    -api {page_cdefinition}]

    pluginmgr::paths $config page::config
    return
}

proc ::page::pluginmgr::InitializeReporting {} {
    variable reportcmd ::page::pluginmgr::ReportStderr
    return
}

proc ::page::pluginmgr::ReportStderr {level text from to} {
    # from = epsilon | list (line col)
    # to   = epsilon | list (line col)
    # line = 5 digits, col = 3 digits

    if {
	($text eq "") &&
	![llength $from] &&
	![llength $to]
    } {
	puts stderr ""
	return
    }

    puts -nonewline stderr $level
    WriteLocation $from
    if {![llength $to]} {
	puts -nonewline stderr { }
    } else {
	puts -nonewline stderr {-}
    }
    WriteLocation $to
    puts -nonewline stderr " "
    puts -nonewline stderr $text
    puts stderr ""
    return
}

proc ::page::pluginmgr::WriteLocation {loc} {
    if {![llength $loc]} {
	set text {         }
    } else {
	set line [lindex $loc 0]
	set col  [lindex $loc 1]
	set text {}
	if {![string length $line]} {
	    append text _____
	} else {
	    append text [string map {{ } _} [format %5d $line]]
	}
	append text @
	if {![string length $col]} {
	    append text ___
	} else {
	    append text [string map {{ } _} [format %3d $col]]
	}
    }
    puts -nonewline stderr $text
    return
}

proc ::page::pluginmgr::AliasOpen {slave file {acc {}} {perm {}}} {

    if {$acc eq ""} {set acc r}

    ::safe::Log $slave =============================================
    ::safe::Log $slave "open $file $acc $perm"

    if {[regexp {[wa+]|(WRONLY)|(RDWR)|(APPEND)|(CREAT)|(TRUNC)} $acc]} {
	# Do not allow write acess.
	::safe::Log $slave "permission denied"
	::safe::Log $slave 0/============================================
	return -code error "permission denied"
    }

    if {[catch {set file [::safe::TranslatePath $slave $file]} msg]} {
	::safe::Log $slave $msg
	::safe::Log $slave "permission denied"
	::safe::Log $slave 1/============================================
	return -code error "permission denied"
    }
    
    # check that the path is in the access path of that slave

    if {[catch {::safe::FileInAccessPath $slave $file} msg]} {
	::safe::Log $slave $msg
	::safe::Log $slave "permission denied"
	::safe::Log $slave 2/============================================
	return -code error "permission denied"
    }

    # do the checks on the filename :

    if {[catch {::safe::CheckFileName $slave $file} msg]} {
	::safe::Log $slave "$file: $msg"
	::safe::Log $slave "$msg"
	::safe::Log $slave 3/============================================
	return -code error $msg
    }

    if {[catch {::interp invokehidden $slave open $file $acc} msg]} {
	::safe::Log $slave "Caught: $msg"
	::safe::Log $slave "script error"
	::safe::Log $slave 4/============================================
	return -code error "script error"
    }

    ::safe::Log $slave =/============================================
    return $msg

}

proc ::page::pluginmgr::Nop {args} {}

proc ::page::pluginmgr::WriteFile {slave file text} {
    if {[file pathtype $file] ne "relative"} {
	set file [file join [pwd] [file tail $fail]]
    }
    file mkdir [file dirname $file]
    fileutil::writeFile      $file $text
    return
}

# ### ### ### ######### ######### #########
## Initialization

namespace eval ::page::pluginmgr {

    # List of functions in the various plugin APIs

    variable reader_api {
	page_rhelp
	page_rlabel
	page_roptions
	page_rconfigure
	page_rrun
	page_rfeature
    }
    variable writer_api {
	page_whelp
	page_wlabel
	page_woptions
	page_wconfigure
	page_wrun
	page_wfeature
    }
    variable transform_api {
	page_thelp
	page_tlabel
	page_toptions
	page_tconfigure
	page_trun
	page_tfeature
    }
    variable commands {
	page_info    {::page::pluginmgr::report info}
	page_warning {::page::pluginmgr::report warning}
	page_error   {::page::pluginmgr::report error}
    }
}

::page::pluginmgr::Initialize

# ### ### ### ######### ######### #########
## Ready

package provide page::pluginmgr 0.2
