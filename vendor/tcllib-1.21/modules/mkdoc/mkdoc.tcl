# -*- mode: tcl ; fill-column: 80 -*-
##############################################################################
#  Author        : Dr. Detlef Groth
#  Created       : Fri Nov 15 10:20:22 2019
#  Last Modified : <220423.0622>
#
#  Description	 : Command line utility and package to extract Markdown documentation 
#                  from programming code if embedded as after comment sequence #' 
#                  manual pages and installation of Tcl files as Tcl modules.
#                  Copy and adaptation of dgw/dgwutils.tcl
#
#  History       : 2019-11-08 version 0.1
#                  2019-11-28 version 0.2
#                  2020-02-26 version 0.3
#                  2020-11-10 Release 0.4
#                  2020-12-30 Release 0.5 (rox2md)
#                  2022-02-09 Release 0.6
#                  2022-04-XX Release 0.7 (minimal)
#	
##############################################################################
#
# Copyright (c) 2019-2022  Dr. Detlef Groth, E-mail: detlef(at)dgroth(dot)de
# 
# This library is free software; you can use, modify, and redistribute it for
# any purpose, provided that existing copyright notices are retained in all
# copies and that this notice is included verbatim in any distributions.
# 
# This software is distributed WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
##############################################################################
#' ---
#' title: mkdoc::mkdoc 0.7.0
#' author: Detlef Groth, Schwielowsee, Germany
#' css: mkdoc.css
#' ---
#' 
#' <center> Manual: [short (doctools)](mkdoc.html) - [long (mkdoc)](mkdoc-mkdoc.html) </center>
#'
#' ## NAME
#'
#' **mkdoc::mkdoc**  - Tcl package and command line application to extract and format 
#' embedded programming documentation from source code files written in Markdown or
#' doctools format and optionally converting it into HTML.
#'
#' ## <a name='toc'></a>TABLE OF CONTENTS
#' 
#'  - [SYNOPSIS](#synopsis)
#'  - [DESCRIPTION](#description)
#'  - [COMMAND](#command)
#'      - [mkdoc::mkdoc](#mkdoc)
#'      - [mkdoc::run](#run)
#'  - [EXAMPLE](#example)
#'  - [BASIC FORMATTING](#format)
#'  - [INSTALLATION](#install)
#'  - [SEE ALSO](#see)
#'  - [CHANGES](#changes)
#'  - [TODO](#todo)
#'  - [AUTHOR](#authors)
#'  - [LICENSE AND COPYRIGHT](#license)
#'
#' ## <a name='synopsis'>SYNOPSIS</a>
#' 
#' Usage as package:
#'
#' ```
#' package require mkdoc::mkdoc
#' mkdoc::mkdoc inputfile outputfile ?-css file.css?
#' ```
#'
#' Usage as command line application for extraction of Markdown comments prefixed with `#'`:
#'
#' ```
#' mkdoc inputfile outputfile ?--css file.css?
#' ```
#'
#' Usage as command line application for conversion of Markdown to HTML:
#'
#' ```
#' mkdoc inputfile.md outputfile.html ?--css file.css?
#' ```
#'
#' ## <a name='description'>DESCRIPTION</a>
#' 
#' **mkdoc::mkdoc**  extracts embedded Markdown or doctools documentation from source code files
#' and  as well converts Markdown the output to HTML if desired.
#' The documentation inside the source code must be prefixed with the `#'` character sequence.
#' The file extension of the output file determines the output format. 
#' File extensions can bei either `.md` for Markdown output, `.man` for doctools output or `.html` for html output.
#' The latter requires the tcllib Markdown or the doctools extensions to be installed.
#' If the file extension of the inputfile is *.md* and file extension of the output files is *.html* 
#' there will be simply a conversion from a Markdown to a HTML file.
#'
#' The file `mkdoc.tcl` can be as well directly used as a console application. 
#' An explanation on how to do this, is given in the section [Installation](#install).
#'
#' ## <a name='command'>COMMAND</a>
#'
#'  <a name="mkdoc"> </a>
#' **mkdoc::mkdoc** *infile outfile ?-css file.css?*
#' 
#' > Extracts the documentation in Markdown format from *infile* and writes the documentation 
#'    to *outfile* either in Markdown, Doctools  or HTML format. 
#' 
#' > - *infile* - file with embedded markdown documentation
#'   - *outfile* -  name of output file extension
#'   - *-css cssfile* if outfile is an HTML file use the given *cssfile*
#'     
#' > If the file extension of the outfile is either html or htm a HTML file is created. If the output file has other 
#'   file extension the documentation after _#'_ comments is simply extracted and stored in the given _outfile_, *-mode* flag  (one of -html, -md, -pandoc) is not given, the output format is taken from the file extension of the output file, either *.html* for HTML or *.md* for Markdown format. This deduction from the filetype can be overwritten giving either `-html` or `-md` as command line flags. If as mode `-pandoc` is given, the Markdown markup code as well contains the YAML header.
#'   If infile has the extension .md (Markdown) or -man (Doctools) than conversion to html will be performed, outfile file extension
#'   In this case must be .html. If output is html a *-css* flag can be given to use the given stylesheet file instead of the default style sheet embedded within the mkdoc code.
#'  
#' > Example:
#'
#' > ```
#' package require mkdoc::mkdoc
#' mkdoc::mkdoc mkdoc.tcl mkdoc.html
#' mkdoc::mkdoc mkdoc.tcl mkdoc.md 
#' > ```

package require Tcl 8.6

package require yaml
package require Markdown
package require hook

package provide mkdoc 0.7.0

namespace eval mkdoc {
    variable deindent [list \n\t \n "\n    " \n]
    
    variable htmltemplate [string map $deindent {
	<!DOCTYPE html>
	<html>
	<head>
	<meta http-equiv="Content-Security-Policy" content="default-src 'self' data: ; script-src 'self' 'nonce-d717cfb5d902616b7024920ae20346a8494f7832145c90e0' ; style-src 'self' 'unsafe-inline'" />
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
	<meta name="title" content="$document(title)">
	<meta name="author" content="$document(author)">
	<title>$document(title)</title>
	$style
	</head>
	<body>
    }]

    variable htmlstart [string map $deindent {
	<h1 class="title">$document(title)</h1>
	<h2 class="author">$document(author)</h2>
	<h2 class="date">$document(date)</h2>
    }]

    variable mkdocstyle [string map $deindent {
	body {
	    margin-left: 10%; margin-right: 10%;
	    font-family: Palatino, "Palatino Linotype", "Palatino LT STD", "Book Antiqua", Georgia, serif;
	    max-width: 90%;
	}
	pre {
	    padding-top:	1ex;
	    padding-bottom:	1ex;
	    padding-left:	2ex;
	    padding-right:	1ex;
	    width:		100%;
	    color: 		black;
	    background: 	#fff4e4;
	    border-top:		1px solid black;
	    border-bottom:		1px solid black;
	    font-family: Monaco, Consolas, "Liberation Mono", Menlo, Courier, monospace;
	}
	a {
	    text-decoration: none
	}
	pre.synopsis {
	    background: #cceeff;
	}
	pre.code code.tclin {
	    background-color: #ffeeee;
	}
	pre.code code.tclout {
	    background-color: #ffffee;
	}
	code {
	    font-family: Consolas, "Liberation Mono", Menlo, Courier, monospace;
	}
	h1,h2, h3,h4 {
	    font-family:	sans-serif;
	    background: 	transparent;
	}
	h1 {
	    font-size: 120%;
	    text-align: center;
	}

	h2.author, h2.date {
	    text-align: center;
	    color: black;
	}
	h2 {    font-size: 110%; }
	h3, h4 {  font-size: 100% }
	div.title h1 {
	    font-family: sans-serif;
	    font-size:   120%;
	    background:  transparent;
	    text-align:  center;
	    color:       black;
	}
	div.author h3, div.date h3 {
	    font-family:	sans-serif;
	    font-size:	110%;
	    background: 	transparent;
	    text-align:	center;
	    color: black ;
	}
	h2, h3 {
	    margin-top:  1em;
	    font-family: sans-serif;
	    font-size:	 110%;
	    color:	 #005A9C;
	    background:  transparent;
	    text-align:	 left;
	}
    }]
} 

proc mkdoc::mkdoc {filename outfile args} {
    variable htmltemplate
    variable htmlstart
    variable mkdocstyle

    array set arg [list -css ""]
    array set arg $args
    if {[file extension $filename] eq [file extension $outfile]} {
	return -code error "Error: infile and outfile must have different file extensions!"
    }
    set outmode html
    if {[file extension $outfile] in [list .md .man]} {
        set outmode markup
    }
    set inmode  code
    if {[file extension $filename] in [list .md .man]} {
        set inmode markup
    }

    hook call mkdoc::mkdoc Processing $filename $inmode $outmode
    
    set markdown ""
    if [catch {
	open $filename r
    } infh] {
        return -code error "Cannot open $filename: $infh"
    } else {
        set flag false
        while {[gets $infh line] >= 0} {
	    if {[regexp {^\s*#' +#include +"(.*)"} $line -> include]} {
                if [catch {
		    open $include r
		} iinfh] {
                    return -code error "Cannot open include file $include: $iinfh"
                } else {
                    #set ilines [read $iinfh]
                    while {[gets $iinfh iline] >= 0} {
                        # Process line
                        append markdown "$iline\n"
                    }
                    close $iinfh
                }
            } elseif {$inmode eq "code" && [regexp {^\s*#' ?(.*)} $line -> md]} {
                append markdown "$md\n"
            } elseif {$inmode eq "markup"} {
                append markdown "$line\n"
            }
        }
        close $infh
        set yamldict \
	    [dict create \
		 title  "Documentation [file tail [file rootname $filename]]" \
		 author NN \
		 date   [clock format [clock seconds] -format "%Y-%m-%d"] \
		 css    mkdoc.css]

	hook call mkdoc::mkdoc Header/Defaults $yamldict

	set mdhtml ""
        set yamlflag false
        set yamltext ""
        set hasyaml false
        set indent ""
        set header $htmltemplate
        set lnr 0
        foreach line [split $markdown "\n"] {
            incr lnr 
            if {$lnr < 5 && !$yamlflag && [regexp {^---} $line]} {
                set yamlflag true
            } elseif {$yamlflag && [regexp {^---} $line]} {
                set hasyaml true
		
                set yamldict [dict merge $yamldict [yaml::yaml2dict $yamltext]]

		hook call mkdoc::mkdoc Header/YAML $yamldict

                set yamlflag false
            } elseif {$yamlflag} {
                append yamltext "$line\n"
            } else {
                set line [regsub -all {!\[\]\((.+?)\)} $line "<image src=\"\\1\"></img>"]
                append mdhtml "$indent$line\n"
            }
        }
        if {$arg(-css) ne ""} {
            dict set yamldict css $arg(-css)
        }

	# Regenerate yamltext from the final dict (to report the final CSS reference)
	set yamltext "---\n"
	foreach k [lsort -dict [dict keys $yamldict]] {
	    append yamltext "${k}: [dict get $yamldict $k]\n"
	}
	append yamltext "---"

	hook call mkdoc::mkdoc Header/Final $yamldict
	
	set style <style>$mkdocstyle</style>

        if {$outmode eq "html"} {
            if {[dict get $yamldict css] ne "mkdoc.css"} {
		# Switch from embedded style to external link
                set style "<link rel=\"stylesheet\" href=\"[dict get $yamldict css]\">"
            }
            set html [Markdown::convert $mdhtml]
            set out [open $outfile w 0644]
            foreach key [dict keys $yamldict] {
                set document($key) [dict get $yamldict $key]
            }
            if {![dict exists $yamldict date]} {
                dict set yamldict date [clock format [clock seconds]]
            }
            set header [subst -nobackslashes -nocommands $header]
            puts $out $header
            if {$hasyaml} {
                set start [subst -nobackslashes -nocommands $htmlstart]            
                puts $out $start
            }
            puts $out $html
            puts $out "</body>\n</html>"
            close $out
        } else {
            set out [open $outfile w 0644]
            puts $out $yamltext
            puts $out $mdhtml
            close $out
        }

	hook call mkdoc::mkdoc Done $outfile
    }
}

#' 
#' <a name="run"> </a>
#' **mkdoc::run** *infile* 
#' 
#' > Source the code in infile and runs the examples in the documentation section
#'    written with Markdown documentation. Below follows an example section which can be
#'    run with `tclsh mkdoc.tcl mkdoc.tcl --run`
#' 
#' ## <a name="example">EXAMPLE</a>
#' 
#' ```
#' puts "Hello mkdoc package"
#' puts "I am in the example section"
#' ```
#' 
proc ::mkdoc::run {argv} {
    set filename [lindex $argv 0]
    if {[llength $argv] == 3} {
        set t [lindex $argv 2]
    } else {
        set t 1
    }
    source $filename
    set extext ""
    set example false
    set excode false
    if [catch {
	open $filename r
    } infh] {
	return -code error "Cannot open $filename: $infh"
    } else {
	while {[gets $infh line] >= 0} {
	    # Process line
	    if {$extext eq "" && \
		    [regexp -nocase {^\s*#'\s+#{2,3}\s.+Example} $line]} {
                set example true
            } elseif {$extext ne "" && \
			  [regexp -nocase "^\\s*#'.*\\s# demo: $extext" $line]} {
                set excode true
            } elseif {$example && [regexp {^\s*#'\s+>?\s*```} $line]} {
                set example false
                set excode true
            } elseif {$excode && [regexp {^\s*#'\s+>?\s*```} $line]} {
                namespace eval :: $code
                break
                # eval code
            } elseif {$excode && [regexp {^\s*#'\s(.+)} $line -> c]} {
                append code "$c\n"
            }
        }
        close $infh
        if {$t > -1} {
            catch {
                update idletasks
                after [expr {$t*1000}]
                destroy .
            }
        }
    }
}

#'
#' ## <a name='format'>BASIC FORMATTING</a>
#' 
#' For a complete list of Markdown formatting commands consult the basic Markdown syntax at [https://daringfireball.net](https://daringfireball.net/projects/markdown/syntax). 
#' Here just the most basic essentials  to create documentation are described.
#' Please note, that formatting blocks in Markdown are separated by an empty line, and empty line in this documenting mode is a line prefixed with the `#'` and nothing thereafter. 
#'
#' **Title and Author**
#' 
#' Title and author can be set at the beginning of the documentation in a so called YAML header. 
#' This header will be as well used by the document converter [pandoc](https://pandoc.org)  to handle various options for later processing if you extract not HTML but Markdown code from your documentation.
#'
#' A YAML header starts and ends with three hyphens. Here is the YAML header of this document:
#' 
#' ```
#' #' ---
#' #' title: mkdoc - Markdown extractor and formatter
#' #' author: Dr. Detlef Groth, Schwielowsee, Germany
#' #' ---
#' ```
#' 
#' Those four lines produce the two lines on top of this document. You can extend the header if you would like to process your document after extracting the Markdown with other tools, for instance with Pandoc.
#' 
#' You can as well specify an other style sheet, than the default by adding
#' the following style information:
#'
#' ```
#' #' ---
#' #' title: mkdoc - Markdown extractor and formatter
#' #' author: Dr. Detlef Groth, Schwielowsee, Germany
#' #' css: tufte.css
#' #' ---
#' ```
#' 
#' Please note, that the indentation is required and it is two spaces.
#'
#' **Headers**
#'
#' Headers are prefixed with the hash symbol, single hash stands for level 1 heading, double hashes for level 2 heading, etc.
#' Please note, that the embedded style sheet centers level 1 and level 3 headers, there are intended to be used
#' for the page title (h1), author (h3) and date information (h3) on top of the page.
#' 
#' ```
#'   #'  ## <a name="sectionname">Section title</a>
#'   #'    
#'   #'  Some free text that follows after the required empty 
#'   #'  line above ...
#' ```
#'
#' This produces a level 2 header. Please note, if you have a section name `synopsis` the code fragments thereafer will be hilighted different than the other code fragments. You should only use level 2 and 3 headers for the documentation. Level 1 header are reserved for the title.
#' 
#' **Lists**
#'
#' Lists can be given either using hyphens or stars at the beginning of a line.
#'
#' ```
#' #' - item 1
#' #' - item 2
#' #' - item 3
#' ```
#' 
#' Here the output:
#'
#' - item 1
#' - item 2
#' - item 3
#' 
#' A special list on top of the help page could be the table of contents list. Here is an example:
#'
#' ```
#' #' ## Table of Contents
#' #'
#' #' - [Synopsis](#synopsis)
#' #' - [Description](#description)
#' #' - [Command](#command)
#' #' - [Example](#example)
#' #' - [Authors](#author)
#' ```
#'
#' This will produce in HTML mode a clickable hyperlink list. You should however create
#' the name targets using html code like so:
#'
#' ```
#' ## <a name='synopsis'>Synopsis</a> 
#' ```
#' 
#' **Hyperlinks**
#'
#' Hyperlinks are written with the following markup code:
#'
#' ```
#' [Link text](URL)
#' ```
#' 
#' Let's link to the Tcler's Wiki:
#' 
#' ```
#' [Tcler's Wiki](https://wiki.tcl-lang.org/)
#' ```
#' 
#' produces: [Tcler's Wiki](https://wiki.tcl-lang.org/)
#'
#' **Indentations**
#'
#' Indentations are achieved using the greater sign:
#' 
#' ```
#' #' Some text before
#' #'
#' #' > this will be indented
#' #'
#' #' This will be not indented again
#' ```
#' 
#' Here the output:
#'
#' Some text before
#' 
#' > this will be indented
#' 
#' This will be not indented again
#'
#' Also lists can be indented:
#' 
#' ```
#' > - item 1
#'   - item 2
#'   - item 3
#' ```
#'
#' produces:
#'
#' > - item 1
#'   - item 2
#'   - item 3
#'
#' **Fontfaces**
#' 
#' Italic font face can be requested by using single stars or underlines at the beginning 
#' and at the end of the text. Bold is achieved by dublicating those symbols:
#' Monospace font appears within backticks.
#' Here an example:
#' 
#' ```
#' #' > I am _italic_ and I am __bold__! But I am programming code: `ls -l`
#' ```
#'
#' > I am _italic_ and I am __bold__! But I am programming code: `ls -l`
#' 
#' **Code blocks**
#'
#' Code blocks can be started using either three or more spaces after the #' sequence 
#' or by embracing the code block with triple backticks on top and on bottom. Here an example:
#' 
#' ```
#' #' ```
#' #' puts "Hello World!"
#' #' ```
#' ```
#'
#' Here the output:
#'
#' ```
#' puts "Hello World!"
#' ```
#'
#' **Images**
#'
#' If you insist on images in your documentation, images can be embedded in Markdown with a syntax close to links.
#' The links here however start with an exclamation mark:
#' 
#' ```
#' #' ![image caption](filename.png)
#' ```
#' 
#' The source code of mkdoc.tcl is a good example for usage of this source code 
#' annotation tool. Don't overuse the possibilities of Markdown, sometimes less is more. 
#' Write clear and concise, don't use fancy visual effects.
#' 
#' **Includes**
#' 
#' mkdoc in contrast to standard markdown as well support includes. Using the `#' #include "filename.md"` syntax 
#' it is possible to include other markdown files. This might be useful for instance to include the same 
#' header or a footer in a set of related files.
#'
#' ## <a name='install'>INSTALLATION</a>
#' 
#' The mkdoc::mkdoc package can be installed either as command line application or as a Tcl module. It requires the markdown, cmdline, yaml and textutils packages from tcllib to be installed.
#' 
#' Installation as command line application is easiest by downloading the file [mkdoc-0.6.bin](https://raw.githubusercontent.com/mittelmark/DGTcl/master/bin/mkdoc-0.6.bin), which
#' contains the main script file and all required libraries, to your local machine. Rename this file to mkdoc, make it executable and coy it to a folder belonging to your PATH variable.
#' 
#' Installation as command line application can be as well done by copying the `mkdoc.tcl` as 
#' `mkdoc` to a directory which is in your executable path. You should make this file executable using `chmod`. 
#' 
#' Installation as Tcl package by copying the mkdoc folder to a folder 
#' which is in your library path for Tcl. Alternatively you can install it as Tcl mode by copying it 
#' in your module path as `mkdoc-0.6.0.tm` for instance. See the [tm manual page](https://www.tcl.tk/man/tcl8.6/TclCmd/tm.htm)
#'
#' ## <a name='see'>SEE ALSO</a>
#' 
#' - [tcllib](https://core.tcl-lang.org/tcllib/doc/trunk/embedded/index.md) for the Markdown and the textutil packages
#' - [pandoc](https://pandoc.org) - a universal document converter
#' - [Ruff!](https://github.com/apnadkarni/ruff) Ruff! documentation generator for Tcl using Markdown syntax as well

#' 
#' ## <a name='changes'>CHANGES</a>
#'
#' - 2019-11-19 Release 0.1
#' - 2019-11-22 Adding direct conversion from Markdown files to HTML files.
#' - 2019-11-27 Documentation fixes
#' - 2019-11-28 Kit version
#' - 2019-11-28 Release 0.2 to fossil
#' - 2019-12-06 Partial R-Roxygen/Markdown support
#' - 2020-01-05 Documentation fixes and version information
#' - 2020-02-02 Adding include syntax
#' - 2020-02-26 Adding stylesheet option --css 
#' - 2020-02-26 Adding files pandoc.css and dgw.css
#' - 2020-02-26 Making standalone file using pkgDeps and mk_tm
#' - 2020-02-26 Release 0.3 to fossil
#' - 2020-02-27 support for \_\_DATE\_\_, \_\_PKGNAME\_\_, \_\_PKGVERSION\_\_ macros  in Tcl code based on package provide line
#' - 2020-09-01 Roxygen2 plugin
#' - 2020-11-09 argument --run supprt
#' - 2020-11-10 Release 0.4
#' - 2020-11-11 command line option  --run with seconds
#' - 2020-12-30 Release 0.5 (rox2md @section support with preformatted, emph and strong/bold)
#' - 2022-02-11 Release 0.6.0 
#'      - parsing yaml header
#'      - workaround for images
#'      - making standalone using tpack.tcl [mkdoc-0.6.bin](https://github.com/mittelmark/DGTcl/blob/master/bin/mkdoc-0.6.bin)
#'      - terminal help update and cleanup
#'      - moved to Github in Wiki
#'      - code cleanup
#' - 2022-04-XX Release 0.7.0
#'      - removing features to simplify the code, so removed plugin support, underline placeholder and sorting facilitites to reduce code size
#'      - creating tcllib compatible manual page
#'
#' ## <a name='todo'>TODO</a>
#'
#' - dtplite support ?
#'
#' ## <a name='authors'>AUTHOR(s)</a>
#'
#' The **mkdoc::mkdoc** package was written by Dr. Detlef Groth, Schwielowsee, Germany.
#'
#' ## <a name='license'>LICENSE AND COPYRIGHT</a>
#'
#' Markdown extractor and converter mkdoc::mkdoc, version 0.7.0
#'
#' Copyright (c) 2019-22  Detlef Groth, E-mail: <detlef(at)dgroth(dot)de>
#' 
#' BSD License type:

#' Sun Microsystems, Inc. The following terms apply to all files a ssociated
#' with the software unless explicitly disclaimed in individual files. 

#' The authors hereby grant permission to use, copy, modify, distribute, and
#' license this software and its documentation for any purpose, provided that
#' existing copyright notices are retained in all copies and that this notice
#' is included verbatim in any distributions. No written agreement, license,
#' or royalty fee is required for any of the authorized uses. Modifications to
#' this software may be copyrighted by their authors and need not follow the
#' licensing terms described here, provided that the new terms are clearly
#' indicated on the first page of each file where they apply. 
#'
#' In no event shall the authors or distributors be liable to any party for
#' direct, indirect, special, incidental, or consequential damages arising out
#' of the use of this software, its documentation, or any derivatives thereof,
#' even if the authors have been advised of the possibility of such damage. 
#'
#' The authors and distributors specifically disclaim any warranties,
#' including, but not limited to, the implied warranties of merchantability,
#' fitness for a particular purpose, and non-infringement. This software is
#' provided on an "as is" basis, and the authors and distributors have no
#' obligation to provide maintenance, support, updates, enhancements, or
#' modifications. 
#'
#' RESTRICTED RIGHTS: Use, duplication or disclosure by the government is
#' subject to the restrictions as set forth in subparagraph (c) (1) (ii) of
#' the Rights in Technical Data and Computer Software Clause as DFARS
#' 252.227-7013 and FAR 52.227-19. 


