A last thing to consider when adding a new package to the collection
is installation.

[para] How to [emph use] the [file installer.tcl] script is documented
in [term {Tcllib - The Installer's Guide}].

[para] Here we document how to extend said installer so that it may
install new package(s) and/or application(s).

[para] In most cases only a single file has to be modified, the
[file support/installation/modules.tcl] holding one command per module
and application to install.

[para] The relevant commands are:

[list_begin definitions]

[call [cmd Module] [arg name] \
      	   [arg code-action] \
      	   [arg doc-action] \
	   [arg example-action]]

Install the packages of module [arg name], found in
[file modules/[arg name]].

[para] The [arg code-action] is responsible for installing the
packages and their index. The system currently provides

[list_begin definitions]

[def [cmd _tcl]] Copy all [file .tcl] files found in
[file modules/[arg name]] into the installation.

[def [cmd _tcr]] As [cmd _tcl], copy the [file .tcl] files found in
the subdirectories of [file modules/[arg name]] as well.

[def [cmd _tci]] As [cmd _tcl], and copy the [file tclIndex.tcl] file
as well.

[def [cmd _msg]] As [cmd _tcl], and copy the subdirectory [file msgs]
as well.

[def [cmd _doc]] As [cmd _tcl], and copy the subdirectory
[file mpformats] as well.

[def [cmd _tex]] As [cmd _tcl], and copy [file .tex] files as well.

[list_end]

[para] The [arg doc-action] is responsible for installing the package
documentation. The system currently provides

[list_begin definitions]
[def [cmd _null]] No documentation available, do nothing.

[def [cmd _man]] Process the [file .man] files found in
[file modules/[arg name]] and install the results (nroff and/or HTML)
in the proper location, as given to the installer.

[para] This is actually a fallback, normally the installer uses the
pre-made formatted documentation found under [file idoc].

[list_end]

[para] The [arg example-action] is responsible for installing the
examples. The system currently provides

[list_begin definitions]
[def [cmd _null]] No examples available, do nothing.

[def [cmd _exa]] Copy the the directory [file examples/[arg name]]
recursively to the install location for examples.

[list_end]

[call [cmd Application] [arg name]]

Install the application with [arg name], found in [file apps].


[call [cmd Exclude] [arg name]]

This command signals to the installer which of the listed modules to
[emph not] install. I.e. they name the deprecated modules of Tcllib.

[list_end]

[para] If, and only if the above actions are not suitable for the new
module then a second file has to be modified,
[file support/installation/actions.tcl].

[para] This file contains the implementations of the available
actions, and is the place where any custom action needed to handle the
special circumstances of module has to be added.
