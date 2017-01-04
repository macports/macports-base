#
# buildutil.tcl -- 
#
# Utility procedures used by the build and install tools.
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
# $Id: buildutil.tcl,v 8.8 2000/07/14 18:08:03 welch Exp $
#------------------------------------------------------------------------------
#

#------------------------------------------------------------------------------
# MakeAbs -- 
#   Base a file name absolute.
#------------------------------------------------------------------------------
proc MakeAbs fname {
    switch [file pathtype $fname] {
        absolute {
            return $fname
        }
        relative {
            return [file join [pwd] $fname]
        }
        volumerelative {
            return [eval file join [linsert [file split $fname] 1 [pwd]]]
        }
    }
}


#------------------------------------------------------------------------------
# CopyFile -- 
#
# Copy the specified file and change the ownership.  If target is a directory,
# then the file is copied to it, otherwise target is a new file name.
# If the source file was owner-executable, the all-executable is set on the
# created file.
#------------------------------------------------------------------------------

proc CopyFile {sourceFile target} {
    global tcl_platform

    if {[lsearch {.orig .diff .rej} [file extension $sourceFile]] >= 0} {
	return
    }
    if {[file isdirectory $target]} {
        set targetFile [file join $target [file tail $sourceFile]]
    } else {
        set targetFile $target
    }

    file delete -force $targetFile
    set sourceFH [open $sourceFile r]
    set targetFH [open $targetFile w]
    fconfigure $sourceFH -translation binary -eofchar {}
    fconfigure $targetFH -translation binary -eofchar {}
    fcopy $sourceFH $targetFH
    close $sourceFH
    close $targetFH

    # Fixup the mode.

    # FIX: chmod not ported to windows yet.
    if ![cequal $tcl_platform(platform) windows] {
        file stat $sourceFile sourceStat
        if {$sourceStat(mode) & 0100} {
            chmod a+rx $targetFile
        } else {
            chmod a+r  $targetFile
        }
    }
}

#------------------------------------------------------------------------------
# CopySubDir --
#
# Recursively copy part of a directory tree, changing ownership and 
# permissions.  This is a utility routine that actually does the copying.
#------------------------------------------------------------------------------

proc CopySubDir {sourceDir destDir} {
    foreach sourceFile [readdir $sourceDir] {
        set sourcePath [file join $sourceDir $sourceFile]
        if [file isdirectory $sourcePath] {
            if [cequal [file tail $sourceFile] "CVS"] {
                continue
            }
            set destFile [file join $destDir $sourceFile]
            file mkdir $destFile
            CopySubDir $sourcePath $destFile
        } else {
            CopyFile $sourcePath $destDir
        }
    }
}

#------------------------------------------------------------------------------
# CopyDir --
#
# Recurisvely copy a directory tree.
#------------------------------------------------------------------------------

proc CopyDir {sourceDir destDir} {
    set cwd [pwd]
    if ![file exists $sourceDir] {
        error "\"$sourceDir\" does not exist"
    }
    if ![file isdirectory $sourceDir] {
        error "\"$sourceDir\" isn't a directory"
    }
    if [cequal [file tail $sourceDir] "CVS"] {
          return
    }
    
    # Dirs must be absolutes paths, as we are going to change directories.

    set sourceDir [MakeAbs $sourceDir]
    set destDir [MakeAbs $destDir]

    file mkdir $destDir
    if ![file isdirectory $destDir] {
        error "\"$destDir\" isn't a directory"
    }
    cd $sourceDir
    set status [catch {CopySubDir . $destDir} msg]
    cd $cwd
    if {$status != 0} {
        global errorInfo errorCode
        error $msg $errorInfo $errorCode
    }
}



