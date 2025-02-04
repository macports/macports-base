# Compiled Runtime In Tcl

 *  Welcome to the C Runtime In Tcl, CriTcl for short, a system to
    build C extension packages for Tcl on the fly, from C code
    embedded within Tcl scripts, for all who wish to make their code
    go faster.

# Website

 *  The main website of this project is http://andreas-kupries.github.io/critcl

    It provides access to pre-made binaries and archives for various
    platforms, and the full documentation, especially the guides to
    building and using Critcl.

    Because of the latter this document contains only the most basic
    instructions on getting, building, and using Critcl.

# Versions

 *  Version 3 is the actively developed version of Critcl, with several
    new features, listed in section **New Features**, below. This version
    has changes to the public API which make it incompatible with packages
    using Critcl version 2.x, or earlier.

 *  The last of version 2 is 2.1, available at the same-named tag in the
    repository. This version is not developed anymore.

# Getting, Building, and Using Critcl

 *  Retrieve the sources:

    ```% git clone http://github.com/andreas-kupries/critcl```

    Your working directory now contains a directory ```critcl```.

 *  Build and install it:

    Install requisites: cmdline, md5; possibly one of tcllibc, Trf, md5c to accelerate md5.

    ```% cd critcl```

    ```% tclsh ./build.tcl install```

    The generated packages are placed into the **[info library]** directory
    of the **tclsh** used to run build.tcl. The **critcl** application script
    is put into the directory of the **tclsh** itself (and modified to
    use this executable). This may require administrative (root) permissions,
    depending on the system setup.

 *  It is expected that a working C compiler is available. Installation and
    setup of such a compiler is platform and vendor specific, and instructions
    for doing so are very much outside of scope for this document. Please find
    and read the documentation, how-tos, etc. for your platform or vendor.

 *  With critcl installed try out one of the examples:

    ```% cd examples/stack```

    ```% critcl -keep -cache B -pkg cstack.tcl```

    ```% critcl -keep -cache B -pkg stackc.tcl```

    ```% tclsh```

    ```> lappend auto_path [pwd]/lib```

    ```> package require stackc```

    ```> stackc create S```

    ```> S push FOO```

    ```> S size```

    ```> S destroy```

    ```> exit```

    ```%```

# New Features

 *  Declaration, export and import of C-APIs through stubs tables.

 *  Generation of source packages from critcl-based code containing a
    TEA-based buildsystem wrapped around the raw critcl.

 *  Declaration, initializaton and use of user-specified configuration
    options. An important use is the declaration and use of custom
    build configurations, like 'link a 3rd party library dynamically,
    statically, build it from copy of its sources, etc.', etc.

 * This is of course not everything. For the details please read the
   Changes sections of the documentation.

# Documentation

 *  Too much to cover here. Please go to http://andreas-kupries.github.io/critcl
    for online reading, or the directories **embedded/www** and
    **embedded/man** for local copies of the documentation in HTML
    and nroff formats, respectively.

# History

 *  **2013-01-21** : Move code to from jcw to andreas-kupries.

 *  **2011-08-18** : Move code to public repository on GitHub

    The Subversion repository at *svn://svn.equi4.com/critcl* is now obsolete.  
    GitHub has the new official repository for Critcl.
