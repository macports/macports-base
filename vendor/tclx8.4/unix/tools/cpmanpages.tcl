#
# cpmanpages.tcl -- 
#
# Tool used during build to copy manual pages to master directories.  This
# program knows the internals of the build, so its very specific to this
# task.
#
# It is run in the following manner:
#
#     cpmanpages ?flags? separator cmd func unix sourceDir targetDir
#
# flags are:
#   o -rmcat - remove any existing "cat" files associated with man pages.
#
# arguments are:
#   o separator - Either "." or "", the separator in the manual page directory
#     name (/usr/man/man1 vs /usr/man/man.1).
#   o cmd - Section to put the Tcl command manual pages in. (*.n pages).
#   o func - Section to put the Tcl C function manual pages in. (*.3 pages).
#   o unix - Section to put the Tcl Unix command manual pages in.
#     Maybe empty. (*.1 pages).
#   o sourceDir - directory containing manual pages to install.
#   o targetDir - manual directory to install pages in.  This is the directory
#     containing the section directories, e.g. /usr/local/man.
#
# If any of these strings are quoted with "@" (e.g. @.@), then the two "@"
# are removed.  This is to work around problems with systems were quoted empty
# strings don't make it past make and shell expansion, resulting in a missing
# argument.
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
# $Id: cpmanpages.tcl,v 8.4 1999/03/31 06:37:59 markd Exp $
#------------------------------------------------------------------------------
#

#------------------------------------------------------------------------------
# Unquote -- 
#
# Remove "@" if they quote a string.
#------------------------------------------------------------------------------

proc Unquote str {
    regsub -- {^@(.*)@$} $str {\1} str
    return $str
}

#------------------------------------------------------------------------------
# CopyManFile -- 
#
# Called to open a copy a man file.  Recursively called to include .so files.
#------------------------------------------------------------------------------

proc CopyManFile {sourceFile targetFH} {

    set sourceFH [open $sourceFile r]

    while {[gets $sourceFH line] >= 0} {
        if [string match {.V[SE]*} $line] continue
        if [string match {.so *} $line] {
            set soFile [string trim [crange $line 3 end]]
            CopyManFile "[file dirname $sourceFile]/$soFile" $targetFH
            continue
        }
        puts $targetFH $line
    }

    close $sourceFH
}

#------------------------------------------------------------------------------
# CopyManPage -- 
#
# Copy the specified manual page and change the ownership.  The manual page
# is edited to remove change bars (.VS and .VE macros). Files included with .so
# are merged in.
#------------------------------------------------------------------------------

proc CopyManPage {sourceFile targetFile} {
    global gzip
    if ![file exists [file dirname $targetFile]] {
        mkdir -path [file dirname $targetFile]
    }
    catch {file delete $targetFile $targetFile.gz}

    set targetFH [open $targetFile w]
    CopyManFile $sourceFile $targetFH
    close $targetFH
    if $gzip {
        exec gzip -9f $targetFile
    }
}

#------------------------------------------------------------------------------
# GetManNames --
#
#   Search a manual page (nroff source) for the name line.  Parse the name
# line into all of the functions or commands that it references.  This isn't
# comprehensive, but it works for all of the Tcl, TclX and Tk man pages.
#
# Parameters:
#   o manFile (I) - The path to the  manual page file.
# Returns:
#   A list contain the functions or commands or {} if the name line can't be
# found or parsed.
#------------------------------------------------------------------------------

proc GetManNames manFile {

   set manFH [open $manFile]

   #
   # Search for name line.  Once found, grab the next line that is not a
   # nroff macro.  If we end up with a blank line, we didn't find it.
   #
   while {[gets $manFH line] >= 0} {
       if [regexp {^.SH NAME.*$} $line] {
           break
       }
   }
   while {[gets $manFH line] >= 0} {
       if {![string match ".*" $line]} break
   }
   close $manFH

   set line [string trim $line]
   if {$line == ""} return

   #
   # Lets try and parse the name list out of the line
   #
   if {![regexp {^(.*)(\\-)} $line {} namePart]} {
       if {![regexp {^(.*)(-)} $line {} namePart]} return
   }

   #
   # This magic converts the name line into a list
   #

   if {[catch {join [split $namePart ,] " "} namePart] != 0} return

   return $namePart

}

#------------------------------------------------------------------------------
# InstallShortMan --
#   Install a manual page on a system that does not have long file names.
#
# Parameters:
#   o sourceFile - Manual page source file path.
#   o targetDir - Directory to install the file in.
#   o extension - Extension to use for the installed file.
# Returns:
#   A list of the man files created, relative to targetDir.
#------------------------------------------------------------------------------

proc InstallShortMan {sourceFile targetDir extension} {

    set manFileName "[file tail [file root $sourceFile]].$extension"

    CopyManPage $sourceFile "$targetDir/$manFileName"

    return $manFileName
}

#------------------------------------------------------------------------------
# InstallLongMan --
#   Install a manual page on a system that has long file names.
#
# Parameters:
#   o sourceFile - Manual page source file path.
#   o targetDir - Directory to install the file in.
#   o extension - Extension to use for the installed file.
# Returns:
#   A list of the man files created, relative to targetDir.  They are all links
# to the same entry.
#------------------------------------------------------------------------------

proc InstallLongMan {sourceFile targetDir extension} {
    global gzip
    set manNames [GetManNames $sourceFile]
    if [lempty $manNames] {
        set baseName [file tail [file root $sourceFile]]
        puts stderr "Warning: can't parse NAME line for man page: $sourceFile."
        puts stderr "         Manual page only available as: $baseName"
        set manNames [list [file tail [file root $sourceFile]]]
    }

    # Copy file to the first name in the list.

    set firstFilePath $targetDir/[lvarpop manNames].$extension
    set created [list [file tail $firstFilePath]]

    CopyManPage $sourceFile $firstFilePath

    # Link it to the rest of the names in the list.

    foreach manName $manNames {
        set targetFile  $targetDir/$manName.$extension
        file delete $targetFile $targetFile.gz
        if $gzip {
            set cmd "link $firstFilePath.gz $targetFile.gz"
        } else {
            set cmd "link $firstFilePath $targetFile"
        }
        if {[catch {
                eval $cmd
            } msg] != 0} {
            puts stderr "error from: $cmd"
            puts stderr "    $msg"
        } else {
            lappend created [file tail $targetFile]
        }
    }
    return $created
}

#------------------------------------------------------------------------------
# InstallManPage --
#   Install a manual page on a system.
#
# Parameters:
#   o sourceFile - Manual page source file path.
#   o manDir - Directory to build the directoy containing the manual files in.
#   o section - Section to install the manual page in.
# Globals
#   o longNames - If long file names are supported.
#   o manSeparator - Character used to seperate man directory name from the
#     section name.
#   o rmcat - true if cat files are to be removed.
#------------------------------------------------------------------------------

proc InstallManPage {sourceFile manDir section} {
    global longNames manSeparator rmcat

    set targetDir "$manDir/man${manSeparator}${section}"

    if $longNames {
        set files [InstallLongMan $sourceFile $targetDir $section]
    } else {
        set files [InstallShortMan $sourceFile $targetDir $section]
    }
   
    if $rmcat {
        foreach file $files {
            catch {
                file delete [list $manDir/cat${manSeparator}${section}/$file]
            }
        }
    }
}

#------------------------------------------------------------------------------
# main prorgam

umask 022

# Parse command line args

set rmcat 0
set gzip 0
while {[string match -* $argv]} {
    set opt [lvarpop argv]
    switch -- $opt {
        -rmcat {set rmcat 1}
        -gzip {set gzip 1}
        default {
            puts stderr "unknown flag: $opt"
        }
    }
}
if {[llength $argv] != 6} {
    puts stderr "wrong # args: cpmanpages ?flags? separator cmd func unix sourceDir targetDir"
    exit 1
}


set manSeparator    [Unquote [lindex $argv 0]]
set sectionXRef(.n) [Unquote [lindex $argv 1]]
set sectionXRef(.3) [Unquote [lindex $argv 2]]
set sectionXRef(.1) [Unquote [lindex $argv 3]]
set sourceDir       [Unquote [lindex $argv 4]]
set targetDir       [Unquote [lindex $argv 5]]

# Remove undefined sections from the array.

foreach sec [array names sectionXRef] {
   if [lempty sectionXRef($sec)] {
       unset sectionXRef($sec)
   }
}

puts stdout "Copying manual pages from $sourceDir to $targetDir"

# Determine if long file names are available.

if ![file exists $targetDir] {
    mkdir -path $targetDir
}
set testName "$targetDir/TclX-long-test-file-name"

if [catch {open $testName w} fh] {
    puts stdout ""
    puts stdout "*** NOTE: long file names do not appear to be available on"
    puts stdout "*** this system. Attempt to create a long named file in"
    puts stdout "*** $targetDir returned the error: $errorCode"
    puts stdout ""
    set longNames 0
} else {
    close $fh
    file delete $testName
    set longNames 1
}

set sourceFiles [glob -- $sourceDir/*.n $sourceDir/*.1 $sourceDir/*.3]

set ignoreFiles {}

# Actually install the files.

foreach sourceFile $sourceFiles {
    if {[lsearch $ignoreFiles [file tail $sourceFile]] >= 0} continue

    set ext [file extension $sourceFile]
    if ![info exists sectionXRef($ext)] {
        puts stderr "WARNING: Don't know how to handle section for $sourceFile,"
        continue
    }
    InstallManPage $sourceFile $targetDir $sectionXRef($ext)
}



