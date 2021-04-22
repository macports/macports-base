
[//000000001]: # (fileutil \- file utilities)
[//000000002]: # (Generated from file 'fileutil\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (fileutil\(n\) 1\.16\.1 tcllib "file utilities")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

fileutil \- Procedures implementing some file utilities

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Warnings and Incompatibilities](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8  
package require fileutil ?1\.16\.1?  

[__::fileutil::lexnormalize__ *path*](#1)  
[__::fileutil::fullnormalize__ *path*](#2)  
[__::fileutil::test__ *path* *codes* ?*msgvar*? ?*label*?](#3)  
[__::fileutil::cat__ \(?*options*? *file*\)\.\.\.](#4)  
[__::fileutil::writeFile__ ?*options*? *file* *data*](#5)  
[__::fileutil::appendToFile__ ?*options*? *file* *data*](#6)  
[__::fileutil::insertIntoFile__ ?*options*? *file* *at* *data*](#7)  
[__::fileutil::removeFromFile__ ?*options*? *file* *at* *n*](#8)  
[__::fileutil::replaceInFile__ ?*options*? *file* *at* *n* *data*](#9)  
[__::fileutil::updateInPlace__ ?*options*? *file* *cmd*](#10)  
[__::fileutil::fileType__ *filename*](#11)  
[__::fileutil::find__ ?*basedir* ?*filtercmd*??](#12)  
[__::fileutil::findByPattern__ *basedir* ?__\-regexp__&#124;__\-glob__? ?__\-\-__? *patterns*](#13)  
[__::fileutil::foreachLine__ *var filename cmd*](#14)  
[__::fileutil::grep__ *pattern* ?*files*?](#15)  
[__::fileutil::install__ ?__\-m__ *mode*? *source* *destination*](#16)  
[__::fileutil::stripN__ *path* *n*](#17)  
[__::fileutil::stripPwd__ *path*](#18)  
[__::fileutil::stripPath__ *prefix* *path*](#19)  
[__::fileutil::jail__ *jail* *path*](#20)  
[__::fileutil::touch__ ?__\-a__? ?__\-c__? ?__\-m__? ?__\-r__ *ref\_file*? ?__\-t__ *time*? *filename* ?*\.\.\.*?](#21)  
[__::fileutil::tempdir__](#22)  
[__::fileutil::tempdir__ *path*](#23)  
[__::fileutil::tempdirReset__](#24)  
[__::fileutil::tempfile__ ?*prefix*?](#25)  
[__::fileutil::maketempdir__ ?__\-prefix__ *str*? ?__\-suffix__ *str*? ?__\-dir__ *str*?](#26)  
[__::fileutil::relative__ *base* *dst*](#27)  
[__::fileutil::relativeUrl__ *base* *dst*](#28)  

# <a name='description'></a>DESCRIPTION

This package provides implementations of standard unix utilities\.

  - <a name='1'></a>__::fileutil::lexnormalize__ *path*

    This command performs purely lexical normalization on the *path* and
    returns the changed path as its result\. Symbolic links in the path are
    *not* resolved\.

    Examples:

        fileutil::lexnormalize /foo/./bar
        => /foo/bar

        fileutil::lexnormalize /foo/../bar
        => /bar

  - <a name='2'></a>__::fileutil::fullnormalize__ *path*

    This command resolves all symbolic links in the *path* and returns the
    changed path as its result\. In contrast to the builtin __file
    normalize__ this command resolves a symbolic link in the last element of
    the path as well\.

  - <a name='3'></a>__::fileutil::test__ *path* *codes* ?*msgvar*? ?*label*?

    A command for the testing of several properties of a *path*\. The
    properties to test for are specified in *codes*, either as a list of
    keywords describing the properties, or as a string where each letter is a
    shorthand for a property to test\. The recognized keywords, shorthands, and
    associated properties are shown in the list below\. The tests are executed in
    the order given to the command\.

    The result of the command is a boolean value\. It will be true if and only if
    the *path* passes all the specified tests\. In the case of the *path* not
    passing one or more test the first failing test will leave a message in the
    variable referenced by *msgvar*, if such is specified\. The message will be
    prefixed with *label*, if it is specified\. *Note* that the variabled
    referenced by *msgvar* is not touched at all if all the tests pass\.

      * *r*ead

        __file readable__

      * *w*rite

        __file writable__

      * *e*xists

        __file exists__

      * e*x*ec

        __file executable__

      * *f*ile

        __file isfile__

      * *d*ir

        __file isdirectory__

  - <a name='4'></a>__::fileutil::cat__ \(?*options*? *file*\)\.\.\.

    A tcl implementation of the UNIX __[cat](\.\./\.\./\.\./\.\./index\.md\#cat)__
    command\. Returns the contents of the specified file\(s\)\. The arguments are
    files to read, with interspersed options configuring the process\. If there
    are problems reading any of the files, an error will occur, and no data will
    be returned\.

    The options accepted are __\-encoding__, __\-translation__,
    __\-eofchar__, and __\-\-__\. With the exception of the last all options
    take a single value as argument, as specified by the tcl builtin command
    __fconfigure__\. The __\-\-__ has to be used to terminate option
    processing before a file if that file's name begins with a dash\.

    Each file can have its own set of options coming before it, and for anything
    not specified directly the defaults are inherited from the options of the
    previous file\. The first file inherits the system default for unspecified
    options\.

  - <a name='5'></a>__::fileutil::writeFile__ ?*options*? *file* *data*

    The command replaces the current contents of the specified *file* with
    *data*, with the process configured by the options\. The command accepts
    the same options as __::fileutil::cat__\. The specification of a
    non\-existent file is legal and causes the command to create the file \(and
    all required but missing directories\)\.

  - <a name='6'></a>__::fileutil::appendToFile__ ?*options*? *file* *data*

    This command is like __::fileutil::writeFile__, except that the previous
    contents of *file* are not replaced, but appended to\. The command accepts
    the same options as __::fileutil::cat__

  - <a name='7'></a>__::fileutil::insertIntoFile__ ?*options*? *file* *at* *data*

    This comment is similar to __::fileutil::appendToFile__, except that the
    new data is not appended at the end, but inserted at a specified location
    within the file\. In further contrast this command has to be given the path
    to an existing file\. It will not create a missing file, but throw an error
    instead\.

    The specified location *at* has to be an integer number in the range
    __0__ \.\.\. \[file size *file*\]\. __0__ will cause insertion of the
    new data before the first character of the existing content, whereas \[file
    size *file*\] causes insertion after the last character of the existing
    content, i\.e\. appending\.

    The command accepts the same options as __::fileutil::cat__\.

  - <a name='8'></a>__::fileutil::removeFromFile__ ?*options*? *file* *at* *n*

    This command is the complement to __::fileutil::insertIntoFile__,
    removing *n* characters from the *file*, starting at location *at*\.
    The specified location *at* has to be an integer number in the range
    __0__ \.\.\. \[file size *file*\] \- *n*\. __0__ will cause the removal
    of the new data to start with the first character of the existing content,
    whereas \[file size *file*\] \- *n* causes the removal of the tail of the
    existing content, i\.e\. the truncation of the file\.

    The command accepts the same options as __::fileutil::cat__\.

  - <a name='9'></a>__::fileutil::replaceInFile__ ?*options*? *file* *at* *n* *data*

    This command is a combination of __::fileutil::removeFromFile__ and
    __::fileutil::insertIntoFile__\. It first removes the part of the
    contents specified by the arguments *at* and *n*, and then inserts
    *data* at the given location, effectively replacing the removed by content
    with *data*\. All constraints imposed on *at* and *n* by
    __::fileutil::removeFromFile__ and __::fileutil::insertIntoFile__
    are obeyed\.

    The command accepts the same options as __::fileutil::cat__\.

  - <a name='10'></a>__::fileutil::updateInPlace__ ?*options*? *file* *cmd*

    This command can be seen as the generic core functionality of
    __::fileutil::replaceInFile__\. It first reads the contents of the
    specified *file*, then runs the command prefix *cmd* with that data
    appended to it, and at last writes the result of that invokation back as the
    new contents of the file\.

    If the executed command throws an error the *file* is not changed\.

    The command accepts the same options as __::fileutil::cat__\.

  - <a name='11'></a>__::fileutil::fileType__ *filename*

    An implementation of the UNIX __[file](\.\./\.\./\.\./\.\./index\.md\#file)__
    command, which uses various heuristics to guess the type of a file\. Returns
    a list specifying as much type information as can be determined about the
    file, from most general \(eg, "binary" or "text"\) to most specific \(eg,
    "gif"\)\. For example, the return value for a GIF file would be "binary
    graphic gif"\. The command will detect the following types of files:
    directory, empty, binary, text, script \(with interpreter\), executable elf,
    executable dos, executable ne, executable pe, graphic gif, graphic jpeg,
    graphic png, graphic tiff, graphic bitmap, html, xml \(with doctype if
    available\), message pgp, binary pdf, text ps, text eps, binary
    gravity\_wave\_data\_frame, compressed bzip, compressed gzip, compressed zip,
    compressed tar, audio wave, audio mpeg, and link\. It further detects
    doctools, doctoc, and docidx documentation files, and tklib diagrams\.

  - <a name='12'></a>__::fileutil::find__ ?*basedir* ?*filtercmd*??

    An implementation of the unix command
    __[find](\.\./\.\./\.\./\.\./index\.md\#find)__\. Adapted from the Tcler's
    Wiki\. Takes at most two arguments, the path to the directory to start
    searching from and a command to use to evaluate interest in each file\. The
    path defaults to "\.", i\.e\. the current directory\. The command defaults to
    the empty string, which means that all files are of interest\. The command
    takes care *not* to lose itself in infinite loops upon encountering
    circular link structures\. The result of the command is a list containing the
    paths to the interesting files\.

    The *filtercmd*, if specified, is interpreted as a command prefix and one
    argument is added to it, the name of the file or directory find is currently
    looking at\. Note that this name is *not* fully qualified\. It has to be
    joined it with the result of __pwd__ to get an absolute filename\.

    The result of *filtercmd* is a boolean value that indicates if the current
    file should be included in the list of interesting files\.

    Example:

        # find .tcl files
        package require fileutil
        proc is_tcl {name} {return [string match *.tcl $name]}
        set tcl_files [fileutil::find . is_tcl]

  - <a name='13'></a>__::fileutil::findByPattern__ *basedir* ?__\-regexp__&#124;__\-glob__? ?__\-\-__? *patterns*

    This command is based upon the __TclX__ command __recursive\_glob__,
    except that it doesn't allow recursion over more than one directory at a
    time\. It uses __::fileutil::find__ internally and is thus able to and
    does follow symbolic links, something the __TclX__ command does not do\.
    First argument is the directory to start the search in, second argument is a
    list of *patterns*\. The command returns a list of all files reachable
    through *basedir* whose names match at least one of the patterns\. The
    options before the pattern\-list determine the style of matching, either
    regexp or glob\. glob\-style matching is the default if no options are given\.
    Usage of the option __\-\-__ stops option processing\. This allows the use
    of a leading '\-' in the patterns\.

  - <a name='14'></a>__::fileutil::foreachLine__ *var filename cmd*

    The command reads the file *filename* and executes the script *cmd* for
    every line in the file\. During the execution of the script the variable
    *var* is set to the contents of the current line\. The return value of this
    command is the result of the last invocation of the script *cmd* or the
    empty string if the file was empty\.

  - <a name='15'></a>__::fileutil::grep__ *pattern* ?*files*?

    Implementation of __[grep](\.\./\.\./\.\./\.\./index\.md\#grep)__\. Adapted
    from the Tcler's Wiki\. The first argument defines the *pattern* to search
    for\. This is followed by a list of *files* to search through\. The list is
    optional and __stdin__ will be used if it is missing\. The result of the
    procedures is a list containing the matches\. Each match is a single element
    of the list and contains filename, number and contents of the matching line,
    separated by a colons\.

  - <a name='16'></a>__::fileutil::install__ ?__\-m__ *mode*? *source* *destination*

    The __install__ command is similar in functionality to the
    __install__ command found on many unix systems, or the shell script
    distributed with many source distributions \(unix/install\-sh in the Tcl
    sources, for example\)\. It copies *source*, which can be either a file or
    directory to *destination*, which should be a directory, unless *source*
    is also a single file\. The ?\-m? option lets the user specify a unix\-style
    mode \(either octal or symbolic \- see __file attributes__\.

  - <a name='17'></a>__::fileutil::stripN__ *path* *n*

    Removes the first *n* elements from the specified *path* and returns the
    modified path\. If *n* is greater than the number of components in *path*
    an empty string is returned\. The number of components in a given path may be
    determined by performing __llength__ on the list returned by __file
    split__\.

  - <a name='18'></a>__::fileutil::stripPwd__ *path*

    If, and only if the *path* is inside of the directory returned by
    \[__pwd__\] \(or the current working directory itself\) it is made relative
    to that directory\. In other words, the current working directory is stripped
    from the *path*\. The possibly modified path is returned as the result of
    the command\. If the current working directory itself was specified for
    *path* the result is the string "__\.__"\.

  - <a name='19'></a>__::fileutil::stripPath__ *prefix* *path*

    If, and only of the *path* is inside of the directory "prefix" \(or the
    prefix directory itself\) it is made relative to that directory\. In other
    words, the prefix directory is stripped from the *path*\. The possibly
    modified path is returned as the result of the command\. If the prefix
    directory itself was specified for *path* the result is the string
    "__\.__"\.

  - <a name='20'></a>__::fileutil::jail__ *jail* *path*

    This command ensures that the *path* is not escaping the directory
    *jail*\. It always returns an absolute path derived from *path* which is
    within *jail*\.

    If *path* is an absolute path and already within *jail* it is returned
    unmodified\.

    An absolute path outside of *jail* is stripped of its root element and
    then put into the *jail* by prefixing it with it\. The same happens if
    *path* is relative, except that nothing is stripped of it\. Before adding
    the *jail* prefix the *path* is lexically normalized to prevent the
    caller from using __\.\.__ segments in *path* to escape the jail\.

  - <a name='21'></a>__::fileutil::touch__ ?__\-a__? ?__\-c__? ?__\-m__? ?__\-r__ *ref\_file*? ?__\-t__ *time*? *filename* ?*\.\.\.*?

    Implementation of __[touch](\.\./\.\./\.\./\.\./index\.md\#touch)__\. Alter the
    atime and mtime of the specified files\. If __\-c__, do not create files
    if they do not already exist\. If __\-r__, use the atime and mtime from
    *ref\_file*\. If __\-t__, use the integer clock value *time*\. It is
    illegal to specify both __\-r__ and __\-t__\. If __\-a__, only
    change the atime\. If __\-m__, only change the mtime\.

    *This command is not available for Tcl versions less than 8\.3\.*

  - <a name='22'></a>__::fileutil::tempdir__

    The command returns the path of a directory where the caller can place
    temporary files, such as "/tmp" on Unix systems\. The algorithm we use to
    find the correct directory is as follows:

      1. The directory set by an invokation of __::fileutil::tempdir__ with
         an argument\. If this is present it is tried exclusively and none of the
         following item are tried\.

      1. The directory named in the TMPDIR environment variable\.

      1. The directory named in the TEMP environment variable\.

      1. The directory named in the TMP environment variable\.

      1. A platform specific location:

           * Windows

             "C:\\TEMP", "C:\\TMP", "\\TEMP", and "\\TMP" are tried in that order\.

           * \(classic\) Macintosh

             The TRASH\_FOLDER environment variable is used\. This is most likely
             not correct\.

           * Unix

             The directories "/tmp", "/var/tmp", and "/usr/tmp" are tried in
             that order\.

    The algorithm utilized is mainly that used in the Python standard library\.
    The exception is the first item, the ability to have the search overridden
    by a user\-specified directory\.

  - <a name='23'></a>__::fileutil::tempdir__ *path*

    In this mode the command sets the *path* as the first and only directory
    to try as a temp\. directory\. See the previous item for the use of the set
    directory\. The command returns the empty string\.

  - <a name='24'></a>__::fileutil::tempdirReset__

    Invoking this command clears the information set by the last call of
    \[__::fileutil::tempdir__ *path*\]\. See the last item too\.

  - <a name='25'></a>__::fileutil::tempfile__ ?*prefix*?

    The command generates a temporary file name suitable for writing to, and the
    associated file\. The file name will be unique, and the file will be writable
    and contained in the appropriate system specific temp directory\. The name of
    the file will be returned as the result of the command\.

    The code was taken from
    [http://wiki\.tcl\.tk/772](http://wiki\.tcl\.tk/772), attributed to Igor
    Volobouev and anon\.

  - <a name='26'></a>__::fileutil::maketempdir__ ?__\-prefix__ *str*? ?__\-suffix__ *str*? ?__\-dir__ *str*?

    The command generates a temporary directory suitable for writing to\. The
    directory name will be unique, and the directory will be writable and
    contained in the appropriate system specific temp directory\. The name of the
    directory will be returned as the result of the command\.

    The three options can used to tweak the behaviour of the command:

      * __\-prefix__ str

        The initial, fixed part of the directory name\. Defaults to __tmp__
        if not specified\.

      * __\-suffix__ str

        The fixed tail of the directory\. Defaults to the empty string if not
        specified\.

      * __\-dir__ str

        The directory to place the new directory into\. Defaults to the result of
        __fileutil::tempdir__ if not specified\.

    The initial code for this was supplied by [Miguel Martinez
    Lopez](mailto:aplicacionamedida@gmail\.com)\.

  - <a name='27'></a>__::fileutil::relative__ *base* *dst*

    This command takes two directory paths, both either absolute or relative and
    computes the path of *dst* relative to *base*\. This relative path is
    returned as the result of the command\. As implied in the previous sentence,
    the command is not able to compute this relationship between the arguments
    if one of the paths is absolute and the other relative\.

    *Note:* The processing done by this command is purely lexical\. Symbolic
    links are *not* taken into account\.

  - <a name='28'></a>__::fileutil::relativeUrl__ *base* *dst*

    This command takes two file paths, both either absolute or relative and
    computes the path of *dst* relative to *base*, as seen from inside of
    the *base*\. This is the algorithm how a browser resolves a relative link
    found in the currently shown file\.

    The computed relative path is returned as the result of the command\. As
    implied in the previous sentence, the command is not able to compute this
    relationship between the arguments if one of the paths is absolute and the
    other relative\.

    *Note:* The processing done by this command is purely lexical\. Symbolic
    links are *not* taken into account\.

# <a name='section2'></a>Warnings and Incompatibilities

  - __1\.14\.9__

    In this version __fileutil::find__'s broken system for handling symlinks
    was replaced with one working correctly and properly enumerating all the
    legal non\-cyclic paths under a base directory\.

    While correct this means that certain pathological directory hierarchies
    with cross\-linked sym\-links will now take about O\(n\*\*2\) time to enumerate
    whereas the original broken code managed O\(n\) due to its brokenness\.

    A concrete example and extreme case is the "/sys" hierarchy under Linux
    where some hundred devices exist under both "/sys/devices" and "/sys/class"
    with the two sub\-hierarchies linking to the other, generating millions of
    legal paths to enumerate\. The structure, reduced to three devices, roughly
    looks like

        /sys/class/tty/tty0 --> ../../dev/tty0
        /sys/class/tty/tty1 --> ../../dev/tty1
        /sys/class/tty/tty2 --> ../../dev/tty1

        /sys/dev/tty0/bus
        /sys/dev/tty0/subsystem --> ../../class/tty
        /sys/dev/tty1/bus
        /sys/dev/tty1/subsystem --> ../../class/tty
        /sys/dev/tty2/bus
        /sys/dev/tty2/subsystem --> ../../class/tty

    The command __fileutil::find__ currently has no way to escape this\. When
    having to handle such a pathological hierarchy It is recommended to switch
    to package __fileutil::traverse__ and the same\-named command it
    provides, and then use the __\-prefilter__ option to prevent the
    traverser from following symbolic links, like so:

        package require fileutil::traverse

        proc NoLinks {fileName} {
            if {[string equal [file type $fileName] link]} {
                return 0
            }
            return 1
        }

        fileutil::traverse T /sys/devices -prefilter NoLinks
        T foreach p {
            puts $p
        }
        T destroy

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *fileutil* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[cat](\.\./\.\./\.\./\.\./index\.md\#cat), [file
utilities](\.\./\.\./\.\./\.\./index\.md\#file\_utilities),
[grep](\.\./\.\./\.\./\.\./index\.md\#grep), [temp
file](\.\./\.\./\.\./\.\./index\.md\#temp\_file), [test](\.\./\.\./\.\./\.\./index\.md\#test),
[touch](\.\./\.\./\.\./\.\./index\.md\#touch), [type](\.\./\.\./\.\./\.\./index\.md\#type)

# <a name='category'></a>CATEGORY

Programming tools
