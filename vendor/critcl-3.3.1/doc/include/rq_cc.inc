[comment {-*- mode: tcl ; fill-column: 90 -*-}]

While [vset critcl] requires a working C compiler to both install itself, and to process
[vset critcl]-based packages installing such is very much out of scope for this document.

[para] Please follow the instructions for the platform and system [vset critcl] is to be
installed on.

[para] The important pieces of information are this:

[list_begin enumerated]

[enum] The path to the directory containing the C compiler binary has to be listed in the
       environment variable [var PATH], for [vset critcl] to find it.

[enum] On Windows(tm) the environment variable [var LIB] has to be present and contain the
       paths of the directories holding Microsoft's libraries. The standard [vset critcl]
       configuration for this platform searches these paths to fine-tune its settings
       based on available libraries and compiler version.

[list_end]

[para] Links of interest:

[list_begin definitions]
[def [uri http://www.tldp.org/HOWTO/HOWTO-INDEX/programming.html]]
[list_end]
