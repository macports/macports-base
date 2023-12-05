#!/usr/bin/env tclsh
#
# $Id$
#
# Upgrade sources.conf for a given prefix (passed as the first and only
# argument).
#
# For an rsync: repository, if it is the standard MacPorts one and not
# already tagged, then make it default, if another wasn't already default.
# For a file:// respository, if it is an svn checkout from the MacPorts
# server, then make it default if another hasn't already been tagged.
#

if {[llength $::argv] == 0} {
   puts "Usage: ${::argv0} <prefix>"
   exit 1
}

set prefix [lindex $::argv 0]
set sourcesConf ${prefix}/etc/macports/sources.conf
if {[catch {set sourcesConfChannel [open $sourcesConf r]}]} {
   exit 0
}


set mktempChannel [open "|/usr/bin/mktemp -t macports_sources_upgrade" r]
set tempfile [read -nonewline $mktempChannel]
close $mktempChannel

set tempfileChannel [open $tempfile w]
set defaultSeen false
set defaultWritten false

while {[gets $sourcesConfChannel line] >= 0} {
   set addDefault false
   if {!$defaultSeen && ![regexp {^\s*#|^$} $line]} {
      if {[regexp {^([\w-]+://\S+)(?:\s+\[(\w+(?:,\w+)*)\])?$} $line -> url flags]} {
         set flags [split $flags ,]
         if {[lsearch $flags default] >= 0} {
            set defaultSeen true
         } elseif {[regexp {rsync://rsync\.(macports|darwinports)\.org/(release|dpupdate)/d?ports} $url]} {
            set addDefault true
         } elseif {[regexp {file://(/.+)} $url -> filepath]} {
            if {[file exists [file join ${filepath} .svn]]} {
               if {![catch {set svnChannel [open "|svn info ${filepath}" r]} err]} {
                  set svnURL {}
                  while {[gets $svnChannel svnLine] >= 0} {
                     regexp {^URL: (.*)} $svnLine -> svnURL
                  }
                  if {[catch {close $svnChannel} err]} {
                     if {![string match "*This client is too old to work with working copy*" $err]} {
                        return -code error $err
                     } else {
                        puts $err
                        puts "WARNING: Unable to check svn URL for '$filepath' as it has been checked out with a newer Subversion client; please manually verify $sourcesConf!"
                     }
                  }
                  if {[regexp {^https?://svn\.(macports|macosforge)\.org/repository/macports/trunk/dports} $svnURL]} {
                     set addDefault true
                  }
               } else {
                  return -code error $err
               }
            }
         }
         if {$addDefault} {
            lappend flags default
            set line "$url \[[join $flags ,]\]"
            set defaultSeen true
            set defaultWritten true
         }
      }
   }
   puts $tempfileChannel $line
}
close $tempfileChannel
close $sourcesConfChannel

if {$defaultWritten} {
   set attributes [file attributes ${sourcesConf}]
   if {[catch {file rename ${sourcesConf} "${sourcesConf}.mpsaved"}]} {
      file rename -force ${sourcesConf} "${sourcesConf}.mpsaved_[clock seconds]"
   }
   file rename ${tempfile} ${sourcesConf}
   eval file attributes ${sourcesConf} $attributes
} else {
   file delete ${tempfile}
   if {!$defaultSeen} {
      puts "[string repeat - 72]
Warning, your source config file at:

   $sourcesConf

needs to have a \[default\] tag added to the primary MacPorts repository,
however the proper entry could not be determined.  Please add the tag
manually by either appending \[default\] to the end of the correct line,
or if there are already tags, adding it to the list, e.g.
\[nosync,default\].
[string repeat - 72]"
   }
}

exit 0

