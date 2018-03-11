#
# buildidx.tcl --
#
# Code to build Tcl package library. Defines the proc `buildpackageindex'.
# 
#------------------------------------------------------------------------------
# Copyright 1992-1999 Karl Lehenbauer and Mark Diekhans.
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose and without fee is hereby granted, provided
# that the above copyright notice appear in all copies.  Karl Lehenbauer and
# Mark Diekhans make no representations about the suitability of this
# software for any purpose.  It is provided "as is" without express or
# implied warranty.
#------------------------------------------------------------------------------
# $Id: buildidx.tcl,v 1.1 2001/10/24 23:31:48 hobbs Exp $
#------------------------------------------------------------------------------
#

namespace eval TclX {


    #--------------------------------------------------------------------------
    # The following code passes around a array containing information about a
    # package.  The following fields are defined
    #
    #   o name - The name of the package.
    #   o offset - The byte offset of the package in the file.
    #   o length - Number of bytes in the current package (EOLN counts as one
    #     byte, even if <cr><lf> is used.  This makes it possible to do a
    #     single read.
    #   o procs - The list of entry point procedures defined for the package.
    #--------------------------------------------------------------------------

    #--------------------------------------------------------------------------
    # Write a line to the index file describing the package.
    #
    proc PutIdxEntry {outfp pkgInfo} {
        puts $outfp [concat [keylget pkgInfo name] \
                            [keylget pkgInfo offset] \
                            [keylget pkgInfo length] \
                            [keylget pkgInfo procs]]
    }

    #--------------------------------------------------------------------------
    # Parse a package header found by a scan match.  Handle backslashed
    # continuation lines.  Make a namespace reference out of the name
    # that the Tcl auto_load function will like.  Global names have no
    # leading :: (for historic reasons), all others are fully qualified.
    #
    proc ParsePkgHeader matchInfoVar {
        upvar $matchInfoVar matchInfo

        set length [expr [clength $matchInfo(line)] + 1]
        set line [string trimright $matchInfo(line)]
        while {[string match {*\\} $line]} {
            set line [csubstr $line 0 [expr [clength $line]-1]]
            set nextLine [gets $matchInfo(handle)]
            append line " " [string trimright $nextLine]
            incr length [expr [clength $nextLine] + 1]
        }
        set procs {}
        foreach p [lrange $line 2 end] {
            lappend procs [auto_qualify $p ::]
        }

        keylset pkgInfo name [lindex $line 1]
        keylset pkgInfo offset $matchInfo(offset)
        keylset pkgInfo procs $procs
        keylset pkgInfo length $length
        return $pkgInfo
    }

    #--------------------------------------------------------------------------
    # Do the actual work of creating a package library index from a library
    # file.
    #
    proc CreateLibIndex {libName} {
        if {[file extension $libName] != ".tlib"} {
            error "Package library `$libName' does not have the extension\
                    `.tlib'"
        }
        set idxName "[file root $libName].tndx"

        catch {file delete $idxName}

        set contectHdl [scancontext create]

        scanmatch $contectHdl "^#@package: " {
            if {[catch {llength $matchInfo(line)}] || 
                ([llength $matchInfo(line)] < 2)} {
                error "invalid package header \"$matchInfo(line)\""
            }
            if ![lempty $pkgInfo] {
                TclX::PutIdxEntry $idxFH $pkgInfo
            }
            set pkgInfo [TclX::ParsePkgHeader matchInfo]
            incr packageCnt
        }

        scanmatch $contectHdl "^#@packend" {
            if [lempty $pkgInfo] {
                error "#@packend without #@package in $libName"
            }
            keylset pkgInfo length \
                    [expr [keylget pkgInfo length] + \
                          [clength $matchInfo(line)]+1]
            TclX::PutIdxEntry $idxFH $pkgInfo
            set pkgInfo {}
        }


        scanmatch $contectHdl {
            if ![lempty $pkgInfo] {
                keylset pkgInfo length \
                        [expr [keylget pkgInfo length] + \
                              [clength $matchInfo(line)]+1]
            }
        }

        try_eval {
            set libFH [open $libName r]
            set idxFH [open $idxName w]
            set packageCnt 0
            set pkgInfo {}
            
            scanfile $contectHdl $libFH
            if {$packageCnt == 0} {
                error "No \"#@package:\" definitions found in $libName"
            }   
            if ![lempty $pkgInfo] {
                TclX::PutIdxEntry $idxFH $pkgInfo
            }
        } {
            catch {file delete $idxName}
            error $errorResult $errorInfo $errorCode
        } {
            catch {close $libFH}
            catch {close $idxFH}
        }

        scancontext delete $contectHdl

        # Set mode and ownership of the index to be the same as the library.
        # Ignore errors if you can't set the ownership.

        # FIX: WIN32, when chmod/chown work.
        global tcl_platform
        if ![cequal $tcl_platform(platform) "unix"] return

        file stat $libName statInfo
        chmod $statInfo(mode) $idxName
        catch {
           chown [list $statInfo(uid) $statInfo(gid)] $idxName
        }
    }

} ;# namespace TclX

#------------------------------------------------------------------------------
# Create a package library index from a library file.
#
proc buildpackageindex {libfilelist} {
    foreach libfile $libfilelist {
        if [catch {
            TclX::CreateLibIndex $libfile
        } errmsg] {
            global errorInfo errorCode
            error "building package index for `$libfile' failed: $errmsg" \
                $errorInfo $errorCode
        }
    }
}

