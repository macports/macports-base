# critclf.tcl --
#     Fortran version of Critcl
#
package require Tcl 8.6 9
package provide critclf 0.3
package require critcl 3.2
package require wrapfort

namespace eval critcl {

    #
    # Public procedures
    #
    namespace export fproc

    variable fsrc   ;# File with Fortran source code

    variable ftype  ;# Fortran types
    set ftype(integer)       "integer :: VNAME"
    set ftype(integer-array) "integer :: size__VNAME; integer, dimension(SIZE) :: VNAME"
    set ftype(real)          "real(kind=kind(1.0d0)) :: VNAME"
    set ftype(real-array)    "integer :: size__VNAME; real, dimension(SIZE) :: VNAME"
    set ftype(double)        "real(kind=kind(1.0d0)) :: VNAME"
    set ftype(double-array)  "integer :: size__VNAME; real(kind=kind(1.0d0)), dimension(SIZE) :: VNAME"

    #
    # Private namespaces for convenience:
    # - Store the configuration parameters
    # - Re-read the configuration file
    #
    namespace eval v {
        variable fconfigvars {fcompile fversion finclude flink foutput
                              foptimize fextra_cflags}
        set configvars [concat $configvars $fconfigvars]
    }
    namespace eval c {
	variable var
        foreach var $::critcl::v::fconfigvars {
            variable $var
        }
	unset var
    }
    readconfig $configfile
}


# Femit, Femitln, Cmdemit --
#     Store Fortran and C code in a private variable for later reference
#
# Arguments:
#     s            Fragment of Fortran code to be stored
#
# Result:
#     None
#
proc ::critcl::Femit {s} {
    append v::fcode($v::curr) $s
}

proc ::critcl::Femitln {{s ""}} {
    Femit "$s\n"
}

proc ::critcl::Cmdemit {s} {
    append v::cmdcode($v::curr) $s
}


# Fdefine --
#     Register the new command for later use
#
# Arguments:
#     name         Name of the new command
#     args         Argument list and body
#
# Result:
#     None
#
proc ::critcl::Fdefine {name args} {
    set v::curr [md5_hex "$name $args"]
    set file [file normalize [info script]]

    set ns [uplevel 2 namespace current]
    if {$ns == "::"} { set ns "" } else { append ns :: }

    set ::auto_index($ns$name) [list [namespace current]::fbuild $file]

    lappend v::code($file,list) $name $v::curr
}



# FortCall --
#     Generate a fragment of C to call the Fortran routine
#
# Arguments:
#     name         Name of the Fortran subroutine
#     carguments   List of arguments (already in C form)
#
# Result:
#     C code fragment
#
# Note:
#     Will probably need to be revised
#
proc ::critcl::FortCall {name carguments} {

    return "    $name\( [join $carguments ,] );"

}


# FortDeclaration --
#     Generate a proper Fortran declaration
#
# Arguments:
#     type         Type of the variable
#     vname        Name of the variable
#     data         Additional information
#
# Result:
#     Fortran declaration
#
proc ::critcl::FortDeclaration {type vname data} {
    variable ftype

    if { [string match "*-array" $type] } {
        set size [string map {"size(" "size__" ")" ""} [lindex $data 1]]
        return [string map [list VNAME $vname SIZE $size] $ftype($type)]
    } else {
        return [string map [list VNAME $vname] $ftype($type)]
    }
}


# fproc --
#     Generate the Tcl/C wrapper for a command written in Fortran
#
# Arguments:
#     name         Name of the Fortran subroutine and Tcl command
#     arguments    Description of the arguments
#     body         Body of the Fortran subroutine
#
# Result:
#     None
#
# Note:
#     This relies for the most part on Wrapfort for the actual
#     generation of the source code
#
proc ::critcl::fproc {name arguments body} {

    ::Wrapfort::incritcl 1

    Fdefine $name $arguments $body

    Femit "subroutine $name\( &\n    "

    set farglist   {}
    set fdecls     {}
    set carglist   {}
    set carguments {}
    foreach {type vname data} $arguments {
        set role [lindex $data 0]

        switch -- $role {
            "input"  -
            "output" -
            "result" {
                lappend fdecls [FortDeclaration $type $vname $data]
                if { ! [string match "*-array" $type] } {
                    lappend farglist $vname
                    lappend carglist "&$vname"
                } else {
                    lappend farglist "$vname, size__$vname"
                    lappend carglist "$vname, &size__$vname"
                    set carguments [concat $carguments "integer size__$vname {assign size($vname)}"]
                }
            }
        }
        if { $type == "external" } {
            lappend farglist $vname
            lappend carglist "$vname"
        }
    }

    Femitln "[join $farglist ",&\n    "])"
    Femitln "    [join $fdecls "\n    "]"
    Femitln $body ;# TODO: use statements
    Femitln "end subroutine $name"

    ::Wrapfort::fproc $name $name \
        [concat $arguments $carguments code [list {Call the routine}] \
            [list [FortCall $name $carglist]]]

    ::Wrapfort::incritcl 0
}


# fexternal --
#     Generate the C wrapper for a Tcl command to be called as an
#     external function in Fortran
#
# Arguments:
#     name         Name of the Fortran interface
#     arguments    Description of the arguments and the surrounding code
#
# Result:
#     None
#
# Note:
#     This relies for the most part on Wrapfort for the actual
#     generation of the source code
#
proc ::critcl::fexternal {name arguments} {

    ::Wrapfort::incritcl 1
    ::Wrapfort::fexternal $name $arguments
    ::Wrapfort::incritcl 0

}


# fcompile --
#     Compile the generated Fortran code
#
# Arguments:
#     file         Name of the Fortran source file
#     src          Complete source code
#     lfd          Log file
#     obj          Name of the object file
#
# Result:
#     None
#
proc ::critcl::fcompile {file src fopts lfd obj} {
    variable run
    set cmdline "$c::fcompile $fopts"
    set outfile $obj
    append cmdline " [subst $c::foutput] $src"
    if {$v::options(language) != ""} {
        # Allow the compiler to determine the type of file
        # otherwise it will try to compile the libs
        append cmdline " -x none"
    }
    if {!$option::debug_symbols} {
        append cmdline " $c::foptimize"
    }
    puts $lfd $cmdline
    set v::failed 0
    interp transfer {} $lfd $run
    if {[catch {
        interp eval $run "exec $cmdline 2>@ $lfd"
        interp transfer $run $lfd {}
        if {!$v::options(keepsrc) && $src ne $file} { file delete $src }
        puts $lfd "$obj: [file size $obj] bytes"
    } err]} {
        puts $err
        interp transfer $run $lfd {}
        puts $lfd "ERROR while compiling code in $file:"
        puts $lfd $err
        incr v::failed
    }
}


# fbuild --
#     Build the library
#
# Arguments:
#     file         Name of the library
#     load         When completed, load the library (or not)
#     prefix       Prefix for the name of the library
#     silent       Suppress error message (or not)
#
# Result:
#     None
#
proc ::critcl::fbuild {{file ""} {load 1} {prefix {}} {silent ""}} {
    if {$file eq ""} {
        set link 1
        set file [file normalize [info script]]
    } else {
        set link 0
    }

    # each unique set of cmds is compiled into a separate extension
    # ??
    set digest [md5_hex "$file $v::code($file,list)"]

    set cache $v::cache
    set cache [file normalize $cache]

    set base [file join $cache ${v::prefix}_$digest]
    set libfile $base

    # the compiled library will be saved for permanent use if the outdir
    # option is set (in which case rebuilds will no longer be automatic)
    if {$v::options(outdir) != ""} {
      set odir [file join [file dirname $file] $v::options(outdir)]
      set oroot [file root [file tail $file]]
      set libfile [file normalize [file join $odir $oroot]]
      file mkdir $odir
    }
    # get the settings for this file into local variables
    foreach x {hdrs srcs libs init ext} {
      set $x [append v::code($file,$x) ""] ;# make sure it exists
    }

    # modify the output file name if debugging symbols are requested
    if {$option::debug_symbols} {
        append libfile _g
    }

    # choose distinct suffix so switching between them causes a rebuild
    switch -- $v::options(combine) {
        ""         -
        dynamic    { append libfile _pic$c::object }
        static     { append libfile _stub$c::object }
        standalone { append libfile $c::object }
    }

    # the init proc name takes a capitalized prefix from the package name
    set ininame stdin ;# in case it's called interactively
    regexp {^\w+} [file tail $file] ininame
    set pkgname $ininame
    set ininame [string totitle $ininame]
    if {$prefix != {}} {
        set pkgname "${prefix}_$pkgname"
        set ininame "${prefix}_$ininame"
    }

    # the shared library we hope to produce
    set target $base$c::sharedlibext
    if {$v::options(force) || ![file exists $target]} {
        file mkdir $cache

        set log [file join $cache [pid].log]
        set lfd [open $log w]
        puts $lfd "\n[clock format [clock seconds]] - $file"

        ::Wrapfort::incritcl 1
        ::Wrapfort::fsource $pkgname $base.c
        ::Wrapfort::incritcl 0
        set ffile   [open ${base}_f.f90 w]
        set cmdfile [open $::Wrapfort::tclfname w]
        set fd      [open ${base}.c w]
        set names   {}

      puts $fd "/* Generated by critcl on [clock format [clock seconds]]
 * source: $file
 * binary: $libfile
 */"
      foreach {name digest} $v::code($file,list) {
          if {[info exists v::code($digest)]} {
              puts $fd $v::code($digest)
          }
          if {[info exists v::fcode($digest)]} {
              puts $ffile $v::fcode($digest)
          }
          if {[info exists v::cmdcode($digest)]} {
              puts $cmdfile $v::cmdcode($digest)
          }
      }
      close $fd
      close $cmdfile
      close $ffile

      set copts [list]
      if {$v::options(language) != ""} {
        lappend fopts -x $v::options(language)
      }
      if {$v::options(I) != ""} {
        lappend copts $c::include$v:::options(I)
      }
      lappend copts $c::include$cache

      set fopts [list]
      if {$v::options(language) != ""} {
        lappend fopts -x $v::options(language)
      }
      if {$v::options(I) != ""} {
        lappend fopts $c::finclude$v:::options(I)
      }
      lappend fopts $c::finclude$cache
      set copies {}
      foreach x $hdrs {
        if {[string index $x 0] == "-"} {
          lappend copts $x
        } else {
          set copy [file join $cache [file tail $x]]
          file delete $copy
          file copy $x $copy
          lappend copies $copy
        }
      }

      fcompile $file ${base}_f.f90 $fopts $lfd $libfile
      append copts " $c::fextra_cflags"

      set c::compile "gcc -c -fPIC"
      set c::cflags ""
      set c::threadflags ""
      set c::output "-o \$outfile"
      set c::optimize "-O"
      set c::link_release ""
      set c::ldoutput ""
      set copts " $c::fextra_cflags"
      file copy -force [file join $::Wrapfort::wrapdir "wrapfort_lib.c"] [file dirname $base]
      compile $file $::Wrapfort::pkgfname $copts $lfd ${base}_c$c::object
      lappend v::objs ${base}_c$c::object

      if { !$v::options(keepsrc) } {
          # file delete $::Wrapfort::tclfname -- AM: this does not work yet!
          #                                          the file remains open somewhere?
          # file delete $base.c
      }

      foreach src $srcs {
          set tail [file tail $src]
          set srcbase [file rootname [file tail $src]]
          if {[file dirname $base] ne [file dirname $src]} {
              set srcbase [file tail [file dirname $src]]_$srcbase
          }
          set obj [file join [file normalize $cache] ${srcbase}$c::object]
          compile $src $src $copts $lfd $obj
          lappend v::objs $obj
      }
      if {($load || $link) && !$v::failed} {
        set cmdline $c::flink
        if {[llength $v::preload]} {
            append cmdline " $c::link_preload"
        }
        set outfile $target
        if {[string length [set ldout [subst $c::ldoutput]]] == 0} {
            set ldout [subst $c::output]
        }
        if {$option::debug_symbols} {
            append cmdline " $c::link_debug $ldout"
        } else {
            append cmdline " $c::strip $c::link_release $ldout"
        }
        if {[string match "win32-*-cl" [Platform]]} {
            regsub -all -- {-l(\S+)} $libs {\1.lib} libs
        }
        append cmdline " $libfile "
#AM     if {[string match "win32-*-cl" [Platform]]} {
#           set f [open [set rsp [file join $cache link.fil]] w]
#           puts $f [join $v::objs \n]
#           close $f
#           append cmdline @$rsp
#       } else {}
            append cmdline [join [lsort -unique $v::objs]]
#      {}
        append cmdline " $libs $v::ldflags"
        puts $lfd "\n$cmdline"
        variable run
        interp transfer {} $lfd $run
        if {[catch {
            interp eval $run "exec $cmdline 2>@ $lfd"
            interp transfer $run $lfd {}
            puts $lfd "$target: [file size $target] bytes"
        } err]} {
            interp transfer $run $lfd {}
            puts $lfd "ERROR while linking $target:"
            incr v::failed
        }
        if {!$v::failed && [llength $v::preload]} {
            # compile preload if necessary
            set outfile [file join [file dirname $base] \
                            preload$c::sharedlibext]
            if {![file readable $outfile]} {
                set src [file join $v::cache preload.c]
                set obj [file join $v::cache preload.o]
                compile $src $src $copts $lfd $obj
                set cmdline "$c::link $obj $c::strip [subst $c::output]"
                puts $lfd "\n$cmdline"
                interp transfer {} $lfd $run
                if {[catch {
                    interp eval $run "exec $cmdline 2>@ $lfd"
                    interp transfer $run $lfd {}
                    puts $lfd "$outfile: [file size $target] bytes"
                } err]} {
                    interp transfer $run $lfd {}
                    puts $lfd "ERROR while linking $outfile:"
                    incr v::failed
                }
            }
        }
      }
      # read build log
      close $lfd
      set lfd [open $log]
      set msgs [read $lfd]
      close $lfd
      file delete -force $log
      # append to critcl log
      set log [file join $cache $v::prefix.log]
      set lfd [open $log a]
      puts $lfd $msgs
      close $lfd
      foreach x $copies { file delete $x }
    }

    if {$v::failed} {
      if {$silent == ""} {
        puts stderr $msgs
        puts stderr "critcl build failed ($file)"
      }
    } elseif {$load} {
        load $target $ininame
    }

    foreach {name digest} $v::code($file,list) {
      if {$name != "" && [info exists v::code($digest)]} {
        unset v::code($digest)
      }
    }
    foreach x {hdrs srcs init} {
      array unset v::code $file,$x
    }
    if {$link} {
      return [list $target $ininame]
    }
    return [list $libfile $ininame]
}
