
[//000000001]: # (ldapx \- LDAP extended object interface)
[//000000002]: # (Generated from file 'ldapx\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2006\-2018 Pierre David <pdav@users\.sourceforge\.net>)
[//000000004]: # (ldapx\(n\) 1\.2 tcllib "LDAP extended object interface")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

ldapx \- LDAP extended object interface

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [OVERVIEW](#section2)

  - [ENTRY CLASS](#section3)

      - [Entry Instance Data](#subsection1)

      - [Entry Options](#subsection2)

      - [Methods for all kinds of entries](#subsection3)

      - [Methods for standard entries only](#subsection4)

      - [Methods for change entries only](#subsection5)

      - [Entry Example](#subsection6)

  - [LDAP CLASS](#section4)

      - [Ldap Instance Data](#subsection7)

      - [Ldap Options](#subsection8)

      - [Ldap Methods](#subsection9)

      - [Ldap Example](#subsection10)

  - [LDIF CLASS](#section5)

      - [Ldif Instance Data](#subsection11)

      - [Ldif Options](#subsection12)

      - [Ldif Methods](#subsection13)

      - [Ldif Example](#subsection14)

  - [References](#section6)

  - [Bugs, Ideas, Feedback](#section7)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require ldapx ?1\.2?  

[*e* __reset__](#1)  
[*e* __dn__ ?*newdn*?](#2)  
[*e* __rdn__](#3)  
[*e* __superior__](#4)  
[*e* __print__](#5)  
[*se* __isempty__](#6)  
[*se* __get__ *attr*](#7)  
[*se* __get1__ *attr*](#8)  
[*se* __set__ *attr* *values*](#9)  
[*se* __set1__ *attr* *value*](#10)  
[*se* __add__ *attr* *values*](#11)  
[*se* __add1__ *attr* *value*](#12)  
[*se* __del__ *attr* ?*values*?](#13)  
[*se* __del1__ *attr* *value*](#14)  
[*se* __getattr__](#15)  
[*se* __getall__](#16)  
[*se* __setall__ *avpairs*](#17)  
[*se* __backup__ ?*other*?](#18)  
[*se* __swap__](#19)  
[*se* __restore__ ?*other*?](#20)  
[*se* __apply__ *centry*](#21)  
[*ce* __change__ ?*new*?](#22)  
[*ce* __diff__ *new* ?*old*?](#23)  
[*la* __error__ ?*newmsg*?](#24)  
[*la* __connect__ *url* ?*binddn*? ?*bindpw*? ?*starttls*?](#25)  
[*la* __disconnect__](#26)  
[*la* __traverse__ *base* *filter* *attrs* *entry* *body*](#27)  
[*la* __search__ *base* *filter* *attrs*](#28)  
[*la* __read__ *base* *filter* *entry* \.\.\. *entry*](#29)  
[*la* __commit__ *entry* \.\.\. *entry*](#30)  
[*li* __channel__ *chan*](#31)  
[*li* __error__ ?*newmsg*?](#32)  
[*li* __read__ *entry*](#33)  
[*li* __write__ *entry*](#34)  

# <a name='description'></a>DESCRIPTION

The __ldapx__ package provides an extended Tcl interface to LDAP directores
and LDIF files\. The __ldapx__ package is built upon the
__[ldap](ldap\.md)__ package in order to get low level LDAP access\.

LDAP access is compatible with RFC 2251
\([http://www\.rfc\-editor\.org/rfc/rfc2251\.txt](http://www\.rfc\-editor\.org/rfc/rfc2251\.txt)\)\.
LDIF access is compatible with RFC 2849
\([http://www\.rfc\-editor\.org/rfc/rfc2849\.txt](http://www\.rfc\-editor\.org/rfc/rfc2849\.txt)\)\.

# <a name='section2'></a>OVERVIEW

The __ldapx__ package provides objects to interact with LDAP directories and
LDIF files with an easy to use programming interface\. It implements three
__[snit](\.\./snit/snit\.md)__::type classes\.

The first class, __entry__, is used to store individual entries\. Two
different formats are available: the first one is the *standard* format, which
represents an entry as read from the directory\. The second format is the
*change* format, which stores differences between two standard entries\.

With these entries, an application which wants to modify an entry in a directory
needs to read a \(standard\) entry from the directory, create a fresh copy into a
new \(standard\) entry, modify the new copy, and then compute the differences
between the two entries into a new \(change\) entry, which may be commited to the
directory\.

Such kinds of modifications are so heavily used that standard entries may
contain their own copy of the original data\. With such a copy, the application
described above reads a \(standard\) entry from the directory, backs\-up the
original data, modifies the entry, and computes the differences between the
entry and its backup\. These differences are then commited to the directory\.

Methods are provided to compute differences between two entries, to apply
differences to an entry in order to get a new entry, and to get or set
attributes in standard entries\.

The second class is the __ldap__ class\. It provides a method to
__connect__ and bind to the directory with a uniform access to LDAP and
LDAPS through an URL \(ldap:// or ldaps://\)\. The __traverse__ control
structure executes a body for each entry found in the directory\. The
__commit__ method applies some changes \(represented as __entry__
objects\) to the directory\. Since some attributes are represented as UTF\-8
strings, the option __\-utf8__ controls which attributes must be converted
and which attributes must not be converted\.

The last class is the __ldif__ class\. It provides a method to associate a
standard Tcl *channel* to an LDIF object\. Then, methods __read__ and
__write__ read or write entries from or to this channel\. This class can make
use of standard or change entries, according to the type of the LDIF file which
may contain either standard entries or change entries \(but not both at the same
time\)\. The option __\-utf8__ works exactly as with the __ldap__ class\.

# <a name='section3'></a>ENTRY CLASS

## <a name='subsection1'></a>Entry Instance Data

An instance of the __entry__ class keeps the following data:

  - dn

    This is the DN of the entry, which includes \(in LDAP terminology\) the RDN
    \(relative DN\) and the Superior parts\.

  - format

    The format may be *uninitialized* \(entry not yet used\), *standard* or
    *change*\. Most methods check the format of the entry, which can be reset
    with the __reset__ method\.

  - attrvals

    In a *standard* entry, this is where the attributes and associated values
    are stored\. Many methods provide access to these informations\. Attribute
    names are always converted into lower case\.

  - backup

    In a *standard* entry, the backup may contain a copy of the dn and all
    attributes and values\. Methods __backup__ and __restore__ manipulate
    these data, and method __diff__ may use this backup\.

  - change

    In a *change* entry, these data represent the modifications\. Such
    modifications are handled by specialized methods such as __apply__ or
    __commit__\. Detailed format should not be used directly by programs\.

    Internally, modifications are represented as a list of elements, each
    element has one of the following formats \(which match the corresponding LDAP
    operations\):

      1. \{__add__ \{attr1 \{val1\.\.\.valn\} attr2 \{\.\.\.\} \.\.\.\}\}

         Addition of a new entry\.

      1. \{__mod__ \{modop \{attr1 ?val1\.\.\.valn?\} attr2 \.\.\.\} \{modop \.\.\.\} \.\.\.\}

         Modification of one or more attributes and/or values, where <modop> can
         be __modadd__, __moddel__ or __modrepl__ \(see the LDAP
         modify operation\)\.

      1. \{__del__\}

         Deletion of an old entry\.

      1. \{__modrdn__ newrdn deleteoldrdn ?newsuperior?\}

         Renaming of an entry\.

## <a name='subsection2'></a>Entry Options

No option is defined by this class\.

## <a name='subsection3'></a>Methods for all kinds of entries

  - <a name='1'></a>*e* __reset__

    This method resets the entry to an uninitialized state\.

  - <a name='2'></a>*e* __dn__ ?*newdn*?

    This method returns the current DN of the entry\. If the optional *newdn*
    is specified, it replaces the current DN of the entry\.

  - <a name='3'></a>*e* __rdn__

    This method returns the RDN part of the DN of the entry\.

  - <a name='4'></a>*e* __superior__

    This method returns the superior part of the DN of the entry\.

  - <a name='5'></a>*e* __print__

    This method returns the entry as a string ready to be printed\.

## <a name='subsection4'></a>Methods for standard entries only

In all methods, attribute names are converted in lower case\.

  - <a name='6'></a>*se* __isempty__

    This method returns 1 if the entry is empty \(i\.e\. without any attribute\)\.

  - <a name='7'></a>*se* __get__ *attr*

    This method returns all values of the attribute *attr*, or the empty list
    if the attribute is not fond\.

  - <a name='8'></a>*se* __get1__ *attr*

    This method returns the first value of the attribute\.

  - <a name='9'></a>*se* __set__ *attr* *values*

    This method sets the values \(list *values*\) of the attribute *attr*\. If
    the list is empty, this method deletes all

  - <a name='10'></a>*se* __set1__ *attr* *value*

    This method sets the values of the attribute *attr* to be an unique value
    *value*\. Previous values, if any, are replaced by the new value\.

  - <a name='11'></a>*se* __add__ *attr* *values*

    This method adds all elements the list *values* to the values of the
    attribute *attr*\.

  - <a name='12'></a>*se* __add1__ *attr* *value*

    This method adds a single value given by the parameter *value* to the
    attribute *attr*\.

  - <a name='13'></a>*se* __del__ *attr* ?*values*?

    If the optional list *values* is specified, this method deletes all
    specified values from the attribute *attr*\. If the argument *values* is
    not specified, this method deletes all values\.

  - <a name='14'></a>*se* __del1__ *attr* *value*

    This method deletes a unique *value* from the attribute *attr*\.

  - <a name='15'></a>*se* __getattr__

    This method returns all attributes names\.

  - <a name='16'></a>*se* __getall__

    This method returns all attributes and values from the entry, packed in a
    list of pairs <attribute, list of values>\.

  - <a name='17'></a>*se* __setall__ *avpairs*

    This method sets at once all attributes and values\. The format of the
    *avpairs* argument is the same as the one returned by method
    __getall__\.

  - <a name='18'></a>*se* __backup__ ?*other*?

    This method stores in an *other* standard entry object a copy of the
    current DN and attributes/values\. If the optional *other* argument is not
    specified, copy is done in the current entry \(in a specific place, see
    section [OVERVIEW](#section2)\)\.

  - <a name='19'></a>*se* __swap__

    This method swaps the current and backup contexts of the entry\.

  - <a name='20'></a>*se* __restore__ ?*other*?

    If the optional argument *other* is given, which must then be a
    *standard* entry, this method restores the current entry into the
    *other* entry\. If the argument *other* argument is not specified, this
    methods restores the current entry from its internal backup \(see section
    [OVERVIEW](#section2)\)\.

  - <a name='21'></a>*se* __apply__ *centry*

    This method applies changes defined in the *centry* argument, which must
    be a *change* entry\.

## <a name='subsection5'></a>Methods for change entries only

  - <a name='22'></a>*ce* __change__ ?*new*?

    If the optional argument *new* is specified, this method modifies the
    change list \(see subsection [Entry Instance Data](#subsection1) for the
    exact format\)\. In both cases, current change list is returned\. Warning:
    values returned by this method should only be used by specialized methods
    such as __apply__ or __commit__\.

  - <a name='23'></a>*ce* __diff__ *new* ?*old*?

    This method computes the differences between the *new* and *old* entries
    under the form of a change list, and stores this list into the current
    *change* entry\. If the optional argument *old* is not specified,
    difference is computed from the entry and its internal backup \(see section
    [OVERVIEW](#section2)\)\. Return value is the computed change list\.

## <a name='subsection6'></a>Entry Example

    package require ldapx

    #
    # Create an entry and fill it as a standard entry with
    # attributes and values
    #
    ::ldapx::entry create e
    e dn "uid=joe,ou=people,o=mycomp"
    e set1 "uid"             "joe"
    e set  "objectClass"     {person anotherObjectClass}
    e set1 "givenName"       "Joe"
    e set1 "sn"              "User"
    e set  "telephoneNumber" {+31415926535 +2182818}
    e set1 "anotherAttr"     "This is a beautiful day, isn't it?"

    puts stdout "e\n[e print]"

    #
    # Create a second entry as a backup of the first, and
    # make some changes on it.
    # Entry is named automatically by snit.
    #

    set b [::ldapx::entry create %AUTO%]
    e backup $b

    puts stdout "$b\n[$b print]"

    $b del  "anotherAttr"
    $b del1 "objectClass" "anotherObjectClass"

    #
    # Create a change entry, a compute differences between first
    # and second entry.
    #

    ::ldapx::entry create c
    c diff e $b

    puts stdout "$c\n[$c print]"

    #
    # Apply changes to first entry. It should be the same as the
    # second entry, now.
    #

    e apply c

    ::ldapx::entry create nc
    nc diff e $b

    puts stdout "nc\n[nc print]"

    #
    # Clean-up
    #

    e destroy
    $b destroy
    c destroy
    nc destroy

# <a name='section4'></a>LDAP CLASS

## <a name='subsection7'></a>Ldap Instance Data

An instance of the __ldap__ class keeps the following data:

  - channel

    This is the channel used by the __[ldap](ldap\.md)__ package for
    communication with the LDAP server\.

  - lastError

    This variable contains the error message which appeared in the last method
    of the __ldap__ class \(this string is modified in nearly all methods\)\.
    The __error__ method may be used to fetch this message\.

## <a name='subsection8'></a>Ldap Options

Options are configured on __ldap__ instances using the __configure__
method\.

The first option is used for TLS parameters:

  - __\-tlsoptions__ *list*

    Specify the set of TLS options to use when connecting to the LDAP server
    \(see the __connect__ method\)\. For the list of valid options, see the
    __[LDAP](ldap\.md)__ package documentation\.

    The default is __\-request 1 \-require 1 \-ssl2 no \-ssl3 no \-tls1 yes \-tls1\.1
    yes \-tls1\.2 yes__\.

    Example:

    $l configure -tlsoptions {-request yes -require yes}

A set of options of the __ldap__ class is used during search operations
\(methods __traverse__, __search__ and __read__, see below\)\.

  - __\-scope__ __base__&#124;__one__&#124;__sub__

    Specify the scope of the LDAP search to be one of __base__, __one__
    or __sub__ to specify a base object, one\-level or subtree search\.

    The default is __sub__\.

  - __\-derefaliases__ __never__&#124;__seach__&#124;__find__&#124;__always__

    Specify how aliases dereferencing is handled: __never__ is used to
    specify that aliases are never derefenced, __always__ that aliases are
    always derefenced, __search__ that aliases are dereferenced when
    searching, or __find__ that aliases are dereferenced only when locating
    the base object for the search\.

    The default is __never__\.

  - __\-sizelimit__ integer

    Specify the maximum number of entries to be retreived during a search\. A
    value of __0__ means no limit\.

    Default is __0__\.

  - __\-timelimit__ integer

    Specify the time limit for a search to complete\. A value of __0__ means
    no limit\.

    Default is __0__\.

  - __\-attrsonly__ __0__&#124;__1__

    Specify if only attribute names are to be retrieved \(value __1__\)\.
    Normally \(value __0__\), attribute values are also retrieved\.

    Default is __0__\.

The last option is used when getting entries or committing changes in the
directory:

  - __\-utf8__ pattern\-yes pattern\-no

    Specify which attribute values are encoded in UTF\-8\. This information is
    specific to the LDAP schema in use by the application, since some attributes
    such as jpegPhoto, for example, are not encoded in UTF\-8\. This option takes
    the form of a list with two regular expressions suitable for the
    __regexp__ command \(anchored by ^ and $\)\. The first specifies which
    attribute names are to be UTF\-8 encoded, and the second selects, among
    those, the attribute names which will not be UTF\-8 encoded\. It is thus
    possible to say: convert all attributes, except jpegPhoto\.

    Default is \{\{\.\*\} \{\}\}, meaning: all attributes are converted, without
    exception\.

## <a name='subsection9'></a>Ldap Methods

  - <a name='24'></a>*la* __error__ ?*newmsg*?

    This method returns the error message that occurred in the last call to a
    __ldap__ class method\. If the optional argument *newmsg* is supplied,
    it becomes the last error message\.

  - <a name='25'></a>*la* __connect__ *url* ?*binddn*? ?*bindpw*? ?*starttls*?

    This method connects to the LDAP server using given URL \(which can be of the
    form [ldap://host:port](ldap://host:port) or
    [ldaps://host:port](ldaps://host:port)\)\. If an optional *binddn*
    argument is given together with the *bindpw* argument, the __connect__
    binds to the LDAP server using the specified DN and password\.

    If the *starttls* argument is given a true value \(__1__, __yes__,
    etc\.\) and the URL uses the [ldap://](ldap://) scheme, a TLS negotiation
    is initiated with the newly created connection, before LDAP binding\. Default
    value: __no__\.

    This method returns 1 if connection was successful, or 0 if an error
    occurred \(use the __[error](\.\./\.\./\.\./\.\./index\.md\#error)__ method to
    get the message\)\.

  - <a name='26'></a>*la* __disconnect__

    This method disconnects \(and unbinds, if necessary\) from the LDAP server\.

  - <a name='27'></a>*la* __traverse__ *base* *filter* *attrs* *entry* *body*

    This method is a new control structure\. It searches the LDAP directory from
    the specified base DN \(given by the *base* argument\) and selects entries
    based on the argument *filter*\. For each entry found, this method fetches
    attributes specified by the *attrs* argument \(or all attributes if it is
    an empty list\), stores them in the *entry* instance of class __entry__
    and executes the script defined by the argument *body*\. Options are used
    to refine the search\.

    Caution: when this method is used, the script *body* cannot perform
    another LDAP search \(methods __traverse__, __search__ or
    __read__\)\.

  - <a name='28'></a>*la* __search__ *base* *filter* *attrs*

    This method searches the directory using the same way as method
    __traverse__\. All found entries are stored in newly created instances of
    class __entry__, which are returned in a list\. The newly created
    instances should be destroyed when they are no longer used\.

  - <a name='29'></a>*la* __read__ *base* *filter* *entry* \.\.\. *entry*

    This method reads one or more entries, using the same search criteria as
    methods __traverse__ and __search__\. All attributes are stored in
    the entries\. This method provides a quick way to read some entries\. It
    returns the number of entries found in the directory \(which may be more than
    the number of read entries\)\. If called without any *entry* argument, this
    method just returns the number of entries found, without returning any data\.

  - <a name='30'></a>*la* __commit__ *entry* \.\.\. *entry*

    This method commits the changes stored in the *entry* arguments\. Each
    *entry* may be either a *change* entry, or a *standard* entry with a
    backup\.

    Note: in the future, this method should use the LDAP transaction extension
    provided by OpenLDAP 2\.3 and later\.

## <a name='subsection10'></a>Ldap Example

        package require ldapx

        #
        # Connects to the LDAP directory using StartTLS
        #

        ::ldapx::ldap create l
        l configure -tlsoptions {-cadir /etc/ssl/certs -request yes -require yes}
        set url "ldap://server.mycomp.com"
        if {! [l connect $url "cn=admin,o=mycomp" "mypasswd" yes]} then {
    	puts stderr "error: [l error]"
    	exit 1
        }

        #
        # Search all entries matching some criterion
        #

        l configure -scope one
        ::ldapx::entry create e
        set n 0
        l traverse "ou=people,o=mycomp" "(sn=Joe*)" {sn givenName} e {
    	puts "dn: [e dn]"
    	puts "  sn:        [e get1 sn]"
    	puts "  givenName: [e get1 givenName]"
    	incr n
        }
        puts "$n entries found"
        e destroy

        #
        # Add a telephone number to some entries
        # Note this modification cannot be done in the "traverse" operation.
        #

        set lent [l search "ou=people,o=mycomp" "(sn=Joe*)" {}]
        ::ldapx::entry create c
        foreach e $lent {
    	$e backup
    	$e add1 "telephoneNumber" "+31415926535"
    	c diff $e
    	if {! [l commit c]} then {
    	    puts stderr "error: [l error]"
    	    exit 1
    	}
    	$e destroy
        }
        c destroy

        l disconnect
        l destroy

# <a name='section5'></a>LDIF CLASS

## <a name='subsection11'></a>Ldif Instance Data

An instance of the __ldif__ class keeps the following data:

  - channel

    This is the Tcl channel used to retrieve or store LDIF file contents\. The
    association between an instance and a channel is made by the method
    __channel__\. There is no need to disrupt this association when the LDIF
    file operation has ended\.

  - format

    LDIF files may contain *standard* entries or *change* entries, but not
    both\. This variable contains the detected format of the file \(when reading\)
    or the format of entries written to the file \(when writing\)\.

  - lastError

    This variable contains the error message which appeared in the last method
    of the __ldif__ class \(this string is modified in nearly all methods\)\.
    The __error__ method may be used to fetch this message\.

  - version

    This is the version of the LDIF file\. Only version 1 is supported: the
    method __read__ can only read from version 1 files, and method
    __write__ only creates version 1 files\.

## <a name='subsection12'></a>Ldif Options

This class defines two options:

  - __\-ignore__ list\-of\-attributes

    This option is used to ignore certain attribute names on reading\. For
    example, to read OpenLDAP replica files \(replog\), one must ignore
    __replica__ and __time__ attributes since they do not conform to the
    RFC 2849 standard for LDIF files\.

    Default is empty list: no attribute is ignored\.

  - __\-utf8__ pattern\-yes pattern\-no

    Specify which attribute values are encoded in UTF\-8\. This information is
    specific to the LDAP schema in use by the application, since some attributes
    such as jpegPhoto, for example, are not encoded in UTF\-8\. This option takes
    the form of a list with two regular expressions suitable for the
    __regexp__ command \(anchored by ^ and $\)\. The first specifies which
    attribute names are to be UTF\-8 encoded, and the second selects, among
    those, the attribute names which will not be UTF\-8 encoded\. It is thus
    possible to say: convert all attributes, except jpegPhoto\.

    Default is \{\{\.\*\} \{\}\}, meaning: all attributes are converted, without
    exception\.

## <a name='subsection13'></a>Ldif Methods

  - <a name='31'></a>*li* __channel__ *chan*

    This method associates the Tcl channel named *chan* with the LDIF
    instance\. It resets the type of LDIF object to *uninitialized*\.

  - <a name='32'></a>*li* __error__ ?*newmsg*?

    This method returns the error message that occurred in the last call to a
    __ldif__ class method\. If the optional argument *newmsg* is supplied,
    it becomes the last error message\.

  - <a name='33'></a>*li* __read__ *entry*

    This method reads the next entry from the LDIF file and stores it in the
    *entry* object of class __entry__\. The entry may be a *standard* or
    *change* entry\.

  - <a name='34'></a>*li* __write__ *entry*

    This method writes the entry given in the argument *entry* to the LDIF
    file\.

## <a name='subsection14'></a>Ldif Example

        package require ldapx

        # This examples reads a LDIF file containing entries,
        # compare them to a LDAP directory, and writes on standard
        # output an LDIF file containing changes to apply to the
        # LDAP directory to match exactly the LDIF file.

        ::ldapx::ldif create liin
        liin channel stdin

        ::ldapx::ldif create liout
        liout channel stdout

        ::ldapx::ldap create la
        if {! [la connect "ldap://server.mycomp.com"]} then {
    	puts stderr "error: [la error]"
    	exit 1
        }
        la configure -scope one

        # Reads LDIF file

        ::ldapx::entry create e1
        ::ldapx::entry create e2
        ::ldapx::entry create c

        while {[liin read e1] != 0} {
    	set base [e1 superior]
    	set id [e1 rdn]
    	if {[la read $base "($id)" e2] == 0} then {
    	    e2 reset
    	}

    	c diff e1 e2
    	if {[llength [c change]] != 0} then {
    	    liout write c
    	}
        }

        la disconnect
        la destroy
        e1 destroy
        e2 destroy
        c destroy
        liout destroy
        liin destroy

# <a name='section6'></a>References

# <a name='section7'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *ldap* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[directory access](\.\./\.\./\.\./\.\./index\.md\#directory\_access),
[internet](\.\./\.\./\.\./\.\./index\.md\#internet),
[ldap](\.\./\.\./\.\./\.\./index\.md\#ldap), [ldap
client](\.\./\.\./\.\./\.\./index\.md\#ldap\_client),
[ldif](\.\./\.\./\.\./\.\./index\.md\#ldif),
[protocol](\.\./\.\./\.\./\.\./index\.md\#protocol), [rfc
2251](\.\./\.\./\.\./\.\./index\.md\#rfc\_2251), [rfc
2849](\.\./\.\./\.\./\.\./index\.md\#rfc\_2849)

# <a name='category'></a>CATEGORY

Networking

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2006\-2018 Pierre David <pdav@users\.sourceforge\.net>
