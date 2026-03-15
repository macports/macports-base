
The core of Tcllib's build system is the script [file installer.tcl]
found in the toplevel directory of a checkout or release.

[para] The
       [example {
         configure ; make install
       }]
       setup available to
       developers on Unix-like systems is just a wrapper around it.

       To go beyond the standard embodied in the wrapper it is
       necessary to directly invoke this script.

[para] On Windows system using it directly is the only way to invoke
       it.

[para] For basic help invoke it as

       [example {
         ./installer.tcl -help
       }]

       This will print a short list of all the available options to
       the standard output channel.

[para] The commands associated with the various [term install] targets
       in the [term Makefile.in] for Unix can be used as additional
       examples on how to use this tool as well.

[para] The installer can operate in GUI and CLI modes.

       By default it chooses the mode automatically, based on if the
       Tcl package [package Tk] can be used or not.

       The option [option -no-gui] can be used to force CLI mode.

[para] Note that it is possible to specify options on the command line
       even if the installer ultimatively selects GUI mode. In that
       case the hardwired defaults and the options determine the data
       presented to the user for editing.

[para] The installer will select a number of defaults for the
       locations of packages, examples, and documentation, and also
       the format of the documentation. The user can overide these
       defaults in the GUI, or by specifying additional options.

       The defaults depend on the platform detected (Unix/Windows) and
       on the [syscmd tclsh] executable used to run the installer.

[para][emph Options]

[list_begin options]
[opt_def -help]

Show the list of options explained here on the standard output channel
and exit.

[opt_def +excluded]

Include deprecated packages in the installation.

[opt_def -no-gui]

Force command line operation of the installer

[opt_def -no-wait]

In CLI mode the installer will by default ask the user to confirm that
the chosen configuration (destination paths, things to install) is
correct before performing any action. Using this option causes the
installer to skip this query and immediately jump to installation.

[opt_def -app-path [arg path]]
[opt_def -example-path [arg path]]
[opt_def -html-path [arg path]]
[opt_def -nroff-path [arg path]]
[opt_def -pkg-path [arg path]]

Declare the destination paths for the applications, examples, html
documentation, nroff manpages, and packages. The defaults are derived
from the location of the [syscmd tclsh] used to run the installer.

[opt_def -dry-run]
[opt_def -simulate]

Run the installer without modifying the destination directories.

[opt_def -apps]
[opt_def -no-apps]
[opt_def -examples]
[opt_def -no-examples]
[opt_def -pkgs]
[opt_def -no-pkgs]
[opt_def -html]
[opt_def -no-html]
[opt_def -nroff]
[opt_def -no-nroff]

(De)activate the installation of applications, examples, packages,
html documentation, and nroff manpages.

[para] Applications, examples, and packages are installed by default.

[para] On Windows the html documentation is installed by default.

[para] On Unix the nroff manpages are installed by default.

[list_end]