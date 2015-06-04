#!/usr/bin/tclsh
#
# Generate a basic template Portfile given a few bits of information
#
# Todo:
# Add remaining portgroup bits
# Add more fields with comments perhaps, so the template is more fully
#    ready for various uses
#

set MY_VERSION 0.2

set supportedGroups [list perl5 php python ruby]


proc printUsage {{channel stderr}} {
   puts $channel "Usage: $::argv0 \[-h\] \[-g portgroup\] <portname> <portversion>"
   puts $channel "   -g   Specify a port group to use (perl5, python, etc)"
   puts $channel "   -h   This help"
   puts $channel ""
   puts $channel "portname      name to use for the port; for group-based ports, don't"
   puts $channel "              use the prefix (py-, p5-, etc) as this will add that"
   puts $channel "              for you when needed"
   puts $channel "portversion   version to use for the port"
}


set groupCode ""
while {[string index [lindex $::argv 0] 0] eq "-"} {
   switch [string range [lindex $::argv 0] 1 end] {
      g {
         if {[llength $::argv] < 2} {
            puts stderr "-g needs a port group"
            printUsage
            exit 1
         }
         set groupCode [lindex $::argv 1]
         if {[lsearch ${supportedGroups} ${groupCode}] == -1} {
            puts "Sorry, port group ${groupCode} is currently not supported"
            puts "Supported: [join ${supportedGroups}]"
            exit 1
         }
         set ::argv [lrange $::argv 1 end]
      }
      h {
         printUsage stdout
         exit 0
      }
      default {
         puts stderr "Unknown option [lindex $::argv 0]"
         printUsage
         exit 1
      }
   }
   set ::argv [lrange $::argv 1 end]
}

if {[llength $::argv] != 2} {
   puts stderr "Error: missing portname or portversion"
   printUsage
   exit 1
}

set portname [lindex $::argv 0]
set portversion [lindex $::argv 1]

puts "# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4"
puts "# \$Id\$"
puts ""
puts "PortSystem          1.0"
switch ${groupCode} {
   perl5 {
      puts "PortGroup           perl5 1.0"
      puts ""
      puts "perl5.branches      5.8 5.10 5.12 5.14 5.16"
      puts "perl5.setup         ${portname} ${portversion}"
      puts "categories-append   replaceme"
   }
   php {
      puts "PortGroup           php 1.1"
      puts ""
      puts "name                php-${portname}"
      puts "version             ${portversion}"
      puts "categories-append   replaceme"
   }
   python {
      puts "PortGroup           python 1.0"
      puts ""
      puts "name                py-${portname}"
      puts "version             ${portversion}"
      puts "categories-append   replaceme"
   }
   ruby {
      puts "PortGroup           ruby 1.0"
      puts ""
      puts "ruby.setup          ${portname} ${portversion}"
      puts "categories-append   replaceme"
   }
   default {
      puts ""
      puts "name                ${portname}"
      puts "version             ${portversion}"
      puts "categories          replaceme"
   }
}
puts "platforms           darwin"
puts "maintainers         replaceme"
puts "license             replaceme"
switch ${groupCode} {
    php {
        puts ""
        puts {php.branches        5.3 5.4 5.5}
        puts {php.pecl            yes}
    }
}
puts ""
puts "description         replaceme"
puts ""
puts "long_description    replaceme"
switch ${groupCode} {
   perl5 {
   }
   php {
   }
   python {
      puts ""
      puts "homepage            replaceme"
      puts "master_sites        replaceme"
      puts {distname            ${portname}-${version}}
   }
   ruby {
   }
   default {
      puts ""
      puts "homepage            replaceme"
      puts "master_sites        replaceme"
   }
}
puts ""
puts "checksums           rmd160  12345 \\"
puts "                    sha256  6789a"
switch ${groupCode} {
   php {
      puts ""
      puts "if {\${name} ne \${subport}} {"
      puts "    depends_lib-append      replaceme"
      puts ""
      puts "    configure.args-append   replaceme"
      puts "}"
   }
   python {
      puts ""
      puts "python.versions     25 26 27"
      puts ""
      puts "if {\${name} ne \${subport}} {"
      puts "    post-destroot {"
      puts {        set docdir ${prefix}/share/doc/${subport}}
      puts {        xinstall -m 755 -d ${destroot}${docdir}}
      puts "        xinstall -m 644 -W $\{worksrcpath\} replaceme \\"
      puts {           ${destroot}${docdir}}
      puts "    }"
      puts "}"
   }
}
