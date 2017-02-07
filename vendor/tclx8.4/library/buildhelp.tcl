#
# buildhelp.tcl --
#
# Program to extract help files from TCL manual pages or TCL script files.
# The help directories are built as a hierarchical tree of subjects and help
# files.  
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
# $Id: buildhelp.tcl,v 1.3 2005/03/25 19:32:48 hobbs Exp $
#------------------------------------------------------------------------------
#
# For nroff man pages, the areas of text to extract are delimited with:
#
#     '\"@help: subjectdir/helpfile
#     '\"@endhelp
#
# start in column one. The text between these markers is extracted and stored
# in help/subjectdir/help.  The file must not exists, this is done to enforced 
# cleaning out the directories before help file generation is started, thus
# removing any stale files.  The extracted text is run through:
#
#     nroff -man|col -xb   {col -b on BSD derived systems}
#
# If there is other text to include in the helpfile, but not in the manual 
# page, the text, along with nroff formatting commands, may be included using:
#
#     '\"@:Other text to include in the help page.
#
# A entry in the brief file, used by apropos my be included by:
#
#     '\"@brief: Short, one line description
#
# These brief request must occur with in the bounds of a help section.
#
# If some header text, such as nroff macros, need to be preappended to the
# text streem before it is run through nroff, then that text can be bracketed
# with:
#
#     '\"@header
#     '\"@endheader
#
# If multiple header blocks are encountered, they will all be preappended.
#
# For TCL script files, which are indentified because they end in ".tcl",
# the text to be extracted is delimited by:
#
#    #@help: subjectdir/helpfile
#    #@endhelp
#
# And brief lines are in the form:
#
#     #@brief: Short, one line description
#
# The only processing done on text extracted from .tcl files it to replace
# the # in column one with a space.
#
#
#-----------------------------------------------------------------------------
# 
# To generate help:
#
#   buildhelp helpDir brief.brf filelist
#
# o helpDir is the help tree root directory.  helpDir should  exists, but any
#   subdirectories that don't exists will be created.  helpDir should be
#   cleaned up before the start of manual page generation, as this program
#   will not overwrite existing files.
# o brief.brf  is the name of the brief file to create form the @brief entries.
#   It must have an extension of ".brf".  It will be created in helpDir.
# o filelist are the nroff manual pages, or .tcl, .tlib files to extract
#   the help files from. If the suffix is not .tcl or .tlib, a nroff manual
#   page is assumed.
#
#-----------------------------------------------------------------------------

#@package: TclX-buildhelp buildhelp

#-----------------------------------------------------------------------------
# Truncate a file name of a help file if the system does not support long
# file names.  If the name starts with `Tcl_', then this prefix is removed.
# If the name is then over 14 characters, it is truncated to 14 charactes
#  
proc TruncFileName {pathName} {
    global truncFileNames

    if {!$truncFileNames} {
        return $pathName}
    set fileName [file tail $pathName]
    if {"[crange $fileName 0 3]" == "Tcl_"} {
        set fileName [crange $fileName 4 end]}
    set fileName [crange $fileName 0 13]
    return "[file dirname $pathName]/$fileName"
}

#-----------------------------------------------------------------------------
# Proc to ensure that all directories for the specified file path exists,
# and if they don't create them.  Don't use -path so we can set the
# permissions.

proc EnsureDirs {filePath} {
    set dirPath [file dirname $filePath]
    if [file exists $dirPath] return
    foreach dir [split $dirPath /] {
        lappend dirList $dir
        set partPath [join $dirList /]
        if [file exists $partPath] continue

        mkdir $partPath
        chmod u=rwx,go=rx $partPath
    }
}

#-----------------------------------------------------------------------------
# Proc to set up scan context for use by FilterNroffManPage.
# This keeps the a two line cache of the previous two lines encountered
# and the blank lines that followed them.
#

proc CreateFilterNroffManPageContext {} {
    global filterNroffManPageContext

    set filterNroffManPageContext [scancontext create]

    # On finding a page header, drop the previous line (which is
    # the page footer). Also deleting the blank lines followin
    # the last line on the previous page.

    scanmatch $filterNroffManPageContext {@@@BUILDHELP@@@} {
        catch {unset prev2Blanks}
        catch {unset prev1Line}
        catch {unset prev1Blanks}
        set nukeBlanks {}
    }

    # Save blank lines

    scanmatch $filterNroffManPageContext {$^} {
        if ![info exists nukeBlanks] {
            append prev1Blanks \n
        }
    }

    # Non-blank line, save it.  Output the 2nd previous line if necessary.

    scanmatch $filterNroffManPageContext {
        catch {unset nukeBlanks}
        if [info exists prev2Line] {
            puts $outFH $prev2Line
            unset prev2Line
        }
        if [info exists prev2Blanks] {
            puts $outFH $prev2Blanks nonewline
            unset prev2Blanks
        }
        if [info exists prev1Line] {
            set prev2Line $prev1Line
        }
        set prev1Line $matchInfo(line)
        if [info exists prev1Blanks] {
            set prev2Blanks $prev1Blanks
            unset prev1Blanks
        }
    }
}

#-----------------------------------------------------------------------------
# Proc to filter a formatted manual page, removing the page headers and
# footers.  This relies on each manual page having a .TH macro in the form:
#   .TH @@@BUILDHELP@@@ n

proc FilterNroffManPage {inFH outFH} {
    global filterNroffManPageContext

    if ![info exists filterNroffManPageContext] {
        CreateFilterNroffManPageContext
    }

    scanfile $filterNroffManPageContext $inFH

    if [info exists prev2Line] {
        puts $outFH $prev2Line
    }
}

#-----------------------------------------------------------------------------
# Proc to set up scan context for use by ExtractNroffHeader
#

proc CreateExtractNroffHeaderContext {} {
    global extractNroffHeaderContext

    set extractNroffHeaderContext [scancontext create]

    scanmatch $extractNroffHeaderContext {'\\"@endheader[ 	]*$} {
        break
    }
    scanmatch $extractNroffHeaderContext {'\\"@:} {
        append nroffHeader "[crange $matchInfo(line) 5 end]\n"
    }
    scanmatch $extractNroffHeaderContext {
        append nroffHeader "$matchInfo(line)\n"
    }
}

#-----------------------------------------------------------------------------
# Proc to extract nroff text to use as a header to all pass to nroff when
# processing a help file.
#    manPageFH - The file handle of the manual page.
#

proc ExtractNroffHeader {manPageFH} {
    global extractNroffHeaderContext nroffHeader

    if ![info exists extractNroffHeaderContext] {
        CreateExtractNroffHeaderContext
    }
    scanfile $extractNroffHeaderContext $manPageFH
}


#-----------------------------------------------------------------------------
# Proc to set up scan context for use by ExtractNroffHelp
#

proc CreateExtractNroffHelpContext {} {
    global extractNroffHelpContext

    set extractNroffHelpContext [scancontext create]

    scanmatch $extractNroffHelpContext {^'\\"@endhelp[ 	]*$} {
        break
    }

    scanmatch $extractNroffHelpContext {^'\\"@brief:} {
        if $foundBrief {
            error {Duplicate "@brief:" entry}
        }
        set foundBrief 1
        puts $briefHelpFH "$helpName\t[csubstr $matchInfo(line) 11 end]"
        continue
    }

    scanmatch $extractNroffHelpContext {^'\\"@:} {
        puts $nroffFH  [csubstr $matchInfo(line) 5 end]
        continue
    }
    scanmatch $extractNroffHelpContext {^'\\"@help:} {
        error {"@help" found within another help section"}
    }
    scanmatch $extractNroffHelpContext {
        puts $nroffFH $matchInfo(line)
    }
}

#-----------------------------------------------------------------------------
# Proc to extract a nroff help file when it is located in the text.
#    manPageFH - The file handle of the manual page.
#    manLine - The '\"@help: line starting the data to extract.
#

proc ExtractNroffHelp {manPageFH manLine} {
    global helpDir nroffHeader briefHelpFH colArgs
    global extractNroffHelpContext

    if ![info exists extractNroffHelpContext] {
        CreateExtractNroffHelpContext
    }

    set helpName [string trim [csubstr $manLine 9 end]]
    set helpFile [TruncFileName "$helpDir/$helpName"]
    if [file exists $helpFile] {
        error "Help file already exists: $helpFile"
    }
    EnsureDirs $helpFile

    set tmpFile "[file dirname $helpFile]/tmp.[id process]"

    echo "    creating help file $helpName"

    set nroffFH [open "| nroff -man | col $colArgs > $tmpFile" w]

    puts $nroffFH {.TH @@@BUILDHELP@@@ 1}

    set foundBrief 0
    scanfile $extractNroffHelpContext $manPageFH

    # Close returns an error on if anything comes back on stderr, even if
    # its a warning.  Output errors and continue.

    set stat [catch {
        close $nroffFH
    } msg]
    if $stat {
        puts stderr "nroff: $msg"
    }

    set tmpFH [open $tmpFile r]
    set helpFH [open $helpFile w]

    FilterNroffManPage $tmpFH $helpFH

    close $tmpFH
    close $helpFH

    unlink $tmpFile
    chmod a-w,a+r $helpFile
}

#-----------------------------------------------------------------------------
# Proc to set up scan context for use by ExtractScriptHelp
#

proc CreateExtractScriptHelpContext {} {
    global extractScriptHelpContext

    set extractScriptHelpContext [scancontext create]

    scanmatch $extractScriptHelpContext {^#@endhelp[ 	]*$} {
        break
    }

    scanmatch $extractScriptHelpContext {^#@brief:} {
        if $foundBrief {
            error {Duplicate "@brief" entry}
        }
        set foundBrief 1
        puts $briefHelpFH "$helpName\t[csubstr $matchInfo(line) 9 end]"
        continue
    }

    scanmatch $extractScriptHelpContext {^#@help:} {
        error {"@help" found within another help section"}
    }
 
    scanmatch $extractScriptHelpContext {^#$} {
        puts $helpFH ""
    }

    scanmatch $extractScriptHelpContext {
        if {[clength $matchInfo(line)] > 1} {
            puts $helpFH " [csubstr $matchInfo(line) 1 end]"
        } else {
            puts $helpFH $matchInfo(line)
        }
    }
}

#-----------------------------------------------------------------------------
# Proc to extract a tcl script help file when it is located in the text.
#    ScriptPageFH - The file handle of the .tcl file.
#    ScriptLine - The #@help: line starting the data to extract.
#

proc ExtractScriptHelp {scriptPageFH scriptLine} {
    global helpDir briefHelpFH
    global extractScriptHelpContext

    if ![info exists extractScriptHelpContext] {
        CreateExtractScriptHelpContext
    }

    set helpName [string trim [csubstr $scriptLine 7 end]]
    set helpFile "$helpDir/$helpName"
    if {[file exists $helpFile]} {
        error "Help file already exists: $helpFile"
    }
    EnsureDirs $helpFile

    echo "    creating help file $helpName"

    set helpFH [open $helpFile w]

    set foundBrief 0
    scanfile $extractScriptHelpContext $scriptPageFH

    close $helpFH
    chmod a-w,a+r $helpFile
}

#-----------------------------------------------------------------------------
# Proc to scan a nroff manual file looking for the start of a help text
# sections and extracting those sections.
#    pathName - Full path name of file to extract documentation from.
#

proc ProcessNroffFile {pathName} {
   global nroffScanCT scriptScanCT nroffHeader

   set fileName [file tail $pathName]

   set nroffHeader {}
   set manPageFH [open $pathName r]
   set matchInfo(fileName) [file tail $pathName]

   echo "    scanning $pathName"

   scanfile $nroffScanCT $manPageFH

   close $manPageFH
}

#-----------------------------------------------------------------------------
# Proc to scan a Tcl script file looking for the start of a
# help text sections and extracting those sections.
#    pathName - Full path name of file to extract documentation from.
#

proc ProcessTclScript {pathName} {
   global scriptScanCT nroffHeader

   set scriptFH [open "$pathName" r]
   set matchInfo(fileName) [file tail $pathName]

   echo "    scanning $pathName"
   scanfile $scriptScanCT $scriptFH

   close $scriptFH
}

#-----------------------------------------------------------------------------
# build: main procedure.  Generates help from specified files.
#    helpDirPath - Directory were the help files go.
#    briefFile - The name of the brief file to create.
#    sourceFiles - List of files to extract help files from.

proc buildhelp {helpDirPath briefFile sourceFiles} {
    global helpDir truncFileNames nroffScanCT
    global scriptScanCT briefHelpFH colArgs

    echo ""
    echo "Begin building help tree"

    # Determine version of col command to use (no -x on BSD)
    if {[catch {exec col -bx </dev/null >/dev/null 2>/dev/null}]} {
        set colArgs {-b}
    } else {
        set colArgs {-bx}
    }
    set helpDir $helpDirPath
    if {![file exists $helpDir]} {
        mkdir $helpDir
    }

    if {![file isdirectory $helpDir]} {
        error "$helpDir is not a directory or does not exist.\n \
                      This should be the help root directory"
    }

    set status [catch {set tmpFH [open $helpDir/AVeryVeryBigFileName w]}]
    if {$status != 0} {
        set truncFileNames 1
    } else {
        close $tmpFH
        unlink $helpDir/AVeryVeryBigFileName
        set truncFileNames 0
    }

    set nroffScanCT [scancontext create]

    scanmatch $nroffScanCT {'\\"@help:} {
        ExtractNroffHelp $matchInfo(handle) $matchInfo(line)
        continue
    }

    scanmatch $nroffScanCT {^'\\"@header} {
        ExtractNroffHeader $matchInfo(handle)
        continue
    }
    scanmatch $nroffScanCT {^'\\"@endhelp} {
        error [concat {@endhelp" without corresponding "@help:"} \
                 ", offset = $matchInfo(offset)"]
    }
    scanmatch $nroffScanCT {^'\\"@brief} {
        error [concat {"@brief" without corresponding "@help:"} \
                 ", offset = $matchInfo(offset)"]
    }

    set scriptScanCT [scancontext create]
    scanmatch $scriptScanCT {^#@help:} {
        ExtractScriptHelp $matchInfo(handle) $matchInfo(line)
    }

    if {[file extension $briefFile] != ".brf"} {
        error "Brief file \"$briefFile\" must have an extension \".brf\""
    }
    if [file exists $helpDir/$briefFile] {
        error "Brief file \"$helpDir/$briefFile\" already exists"
    }
    set briefHelpFH [open "|sort > $helpDir/$briefFile" w]

    foreach manFile [glob $sourceFiles] {
        set ext [file extension $manFile]
        if {$ext == ".tcl" || $ext == ".tlib"} {
            set status [catch {ProcessTclScript $manFile} msg]
        } else {
            set status [catch {ProcessNroffFile $manFile} msg]
        }
        if {$status != 0} {
            global errorInfo errorCode
            error "Error extracting help from: $manFile" $errorInfo $errorCode
        }
    }

    close $briefHelpFH
    chmod a-w,a+r $helpDir/$briefFile
    echo "Completed extraction of help files"
}



