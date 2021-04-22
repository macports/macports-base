
[//000000001]: # (ftp \- ftp client)
[//000000002]: # (Generated from file 'ftp\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (ftp\(n\) 2\.4\.13 tcllib "ftp client")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

ftp \- Client\-side tcl implementation of the ftp protocol

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [BUGS](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require ftp ?2\.4\.13?  

[__::ftp::Open__ *server* *user* *passwd* ?*options*?](#1)  
[__::ftp::Close__ *handle*](#2)  
[__::ftp::Cd__ *handle* *directory*](#3)  
[__::ftp::Pwd__ *handle*](#4)  
[__::ftp::Type__ *handle* ?__ascii&#124;binary&#124;tenex__?](#5)  
[__::ftp::List__ *handle* ?*pattern*?](#6)  
[__::ftp::NList__ *handle* ?*directory*?](#7)  
[__::ftp::FileSize__ *handle* *file*](#8)  
[__::ftp::ModTime__ *handle* *file*](#9)  
[__::ftp::Delete__ *handle* *file*](#10)  
[__::ftp::Rename__ *handle* *from* *to*](#11)  
[__::ftp::Put__ *handle* \(*local* &#124; \-data *data* &#124; \-channel *chan*\) ?*remote*?](#12)  
[__::ftp::Append__ *handle* \(*local* &#124; \-data *data* &#124; \-channel *chan*\) ?*remote*?](#13)  
[__::ftp::Get__ *handle* *remote* ?\(*local* &#124; \-variable *varname* &#124; \-channel *chan*\)?](#14)  
[__::ftp::Reget__ *handle* *remote* ?*local*? ?*from*? ?*to*?](#15)  
[__::ftp::Newer__ *handle* *remote* ?*local*?](#16)  
[__::ftp::MkDir__ *handle* *directory*](#17)  
[__::ftp::RmDir__ *handle* *directory*](#18)  
[__::ftp::Quote__ *handle* *arg1* *arg2* *\.\.\.*](#19)  
[__::ftp::DisplayMsg__ *handle* *msg* ?*state*?](#20)  

# <a name='description'></a>DESCRIPTION

The ftp package provides the client side of the ftp protocol as specified in RFC
959
\([http://www\.rfc\-editor\.org/rfc/rfc959\.txt](http://www\.rfc\-editor\.org/rfc/rfc959\.txt)\)\.
The package implements both active \(default\) and passive ftp sessions\.

A new ftp session is started with the __::ftp::Open__ command\. To shutdown
an existing ftp session use __::ftp::Close__\. All other commands are
restricted to usage in an an open ftp session\. They will generate errors if they
are used out of context\. The ftp package includes file and directory
manipulating commands for remote sites\. To perform the same operations on the
local site use commands built into the core, like __cd__ or
__[file](\.\./\.\./\.\./\.\./index\.md\#file)__\.

The output of the package is controlled by two state variables,
__::ftp::VERBOSE__ and __::ftp::DEBUG__\. Setting __::ftp::VERBOSE__
to "1" forces the package to show all responses from a remote server\. The
default value is "0"\. Setting __::ftp::DEBUG__ to "1" enables debugging and
forces the package to show all return codes, states, state changes and "real"
ftp commands\. The default value is "0"\.

The command __::ftp::DisplayMsg__ is used to show the different messages
from the ftp session\. The setting of __::ftp::VERBOSE__ determines if this
command is called or not\. The current implementation of the command uses the
__[log](\.\./log/log\.md)__ package of tcllib to write the messages to
their final destination\. This means that the behaviour of
__::ftp::DisplayMsg__ can be customized without changing its implementation\.
For more radical changes overwriting its implementation by the application is of
course still possible\. Note that the default implementation honors the option
__\-output__ to __::ftp::Open__ for a session specific log command\.

*Caution*: The default implementation logs error messages like all other
messages\. If this behaviour is changed to throwing an error instead all commands
in the API will change their behaviour too\. In such a case they will not return
a failure code as described below but pass the thrown error to their caller\.

# <a name='section2'></a>API

  - <a name='1'></a>__::ftp::Open__ *server* *user* *passwd* ?*options*?

    This command is used to start a FTP session by establishing a control
    connection to the FTP server\. The defaults are used for any option not
    specified by the caller\.

    The command takes a host name *server*, a user name *user* and a
    password *password* as its parameters and returns a session handle that is
    an integer number greater than or equal to "0", if the connection is
    successfully established\. Otherwise it returns "\-1"\. The *server*
    parameter must be the name or internet address \(in dotted decimal notation\)
    of the ftp server to connect to\. The *user* and *passwd* parameters must
    contain a valid user name and password to complete the login process\.

    The options overwrite some default values or set special abilities:

      * __\-blocksize__ *size*

        The blocksize is used during data transfer\. At most *size* bytes are
        transfered at once\. The default value for this option is 4096\. The
        package will evaluate the __\-progress callback__ for the session
        after the transfer of each block\.

      * __\-timeout__ *seconds*

        If *seconds* is non\-zero, then __::ftp::Open__ sets up a timeout
        which will occur after the specified number of seconds\. The default
        value is 600\.

      * __\-port__ *number*

        The port *number* specifies an alternative remote port on the ftp
        server on which the ftp service resides\. Most ftp services listen for
        connection requests on the default port 21\. Sometimes, usually for
        security reasons, port numbers other than 21 are used for ftp
        connections\.

      * __\-mode__ *mode*

        The transfer *mode* option determines if a file transfer occurs in
        __active__ or __passive__ mode\. In passive mode the client will
        ask the ftp server to listen on a data port and wait for the connection
        rather than to initiate the process by itself when a data transfer
        request comes in\. Passive mode is normally a requirement when accessing
        sites via a firewall\. The default mode is __active__\.

      * __\-progress__ *callback*

        This *callback* is evaluated whenever a block of data was transfered\.
        See the option __\-blocksize__ for how to specify the size of the
        transfered blocks\.

        When evaluating the *callback* one argument is appended to the
        callback script, the current accumulated number of bytes transferred so
        far\.

      * __\-command__ *callback*

        Specifying this option places the connection into asynchronous mode\. The
        *callback* is evaluated after the completion of any operation\. When an
        operation is running no further operations must be started until a
        callback has been received for the currently executing operation\.

        When evaluating the *callback* several arguments are appended to the
        callback script, namely the keyword of the operation that has completed
        and any additional arguments specific to the operation\. If an error
        occurred during the execution of the operation the callback is given the
        keyword __error__\.

      * __\-output__ *callback*

        This option has no default\. If it is set the default implementation of
        __::ftp::DisplayMsg__ will use its value as command prefix to log
        all internal messages\. The callback will have three arguments appended
        to it before evaluation, the id of the session, the message itself, and
        the connection state, in this order\.

  - <a name='2'></a>__::ftp::Close__ *handle*

    This command terminates the specified ftp session\. If no file transfer is in
    progress, the server will close the control connection immediately\. If a
    file transfer is in progress however, the control connection will remain
    open until the transfers completes\. When that happens the server will write
    the result response for the transfer to it and close the connection
    afterward\.

  - <a name='3'></a>__::ftp::Cd__ *handle* *directory*

    This command changes the current working directory on the ftp server to a
    specified target *directory*\. The command returns 1 if the current working
    directory was successfully changed to the specified directory or 0 if it
    fails\. The target directory can be

      * a subdirectory of the current directory,

      * Two dots, __\.\.__ \(as an indicator for the parent directory of the
        current directory\)

      * or a fully qualified path to a new working directory\.

  - <a name='4'></a>__::ftp::Pwd__ *handle*

    This command returns the complete path of the current working directory on
    the ftp server, or an empty string in case of an error\.

  - <a name='5'></a>__::ftp::Type__ *handle* ?__ascii&#124;binary&#124;tenex__?

    This command sets the ftp file transfer type to either __ascii__,
    __binary__, or __tenex__\. The command always returns the currently
    set type\. If called without type no change is made\.

    Currently only __ascii__ and __binary__ types are supported\. There
    is some early \(alpha\) support for Tenex mode\. The type __ascii__ is
    normally used to convert text files into a format suitable for text editors
    on the platform of the destination machine\. This mainly affects end\-of\-line
    markers\. The type __binary__ on the other hand allows the undisturbed
    transfer of non\-text files, such as compressed files, images and
    executables\.

  - <a name='6'></a>__::ftp::List__ *handle* ?*pattern*?

    This command returns a human\-readable list of files\. Wildcard expressions
    such as "\*\.tcl" are allowed\. If *pattern* refers to a specific directory,
    then the contents of that directory are returned\. If the *pattern* is not
    a fully\-qualified path name, the command lists entries relative to the
    current remote directory\. If no *pattern* is specified, the contents of
    the current remote directory is returned\.

    The listing includes any system\-dependent information that the server
    chooses to include\. For example most UNIX systems produce output from the
    command __ls \-l__\. The command returns the retrieved information as a
    tcl list with one item per entry\. Empty lines and UNIX's "total" lines are
    ignored and not included in the result as reported by this command\.

    If the command fails an empty list is returned\.

  - <a name='7'></a>__::ftp::NList__ *handle* ?*directory*?

    This command has the same behavior as the __::ftp::List__ command,
    except that it only retrieves an abbreviated listing\. This means only file
    names are returned in a sorted list\.

  - <a name='8'></a>__::ftp::FileSize__ *handle* *file*

    This command returns the size of the specified *file* on the ftp server\.
    If the command fails an empty string is returned\.

    *ATTENTION\!* It will not work properly when in ascii mode and is not
    supported by all ftp server implementations\.

  - <a name='9'></a>__::ftp::ModTime__ *handle* *file*

    This command retrieves the time of the last modification of the *file* on
    the ftp server as a system dependent integer value in seconds or an empty
    string if an error occurred\. Use the built\-in command __clock__ to
    convert the retrieves value into other formats\.

  - <a name='10'></a>__::ftp::Delete__ *handle* *file*

    This command deletes the specified *file* on the ftp server\. The command
    returns 1 if the specified file was successfully deleted or 0 if it failed\.

  - <a name='11'></a>__::ftp::Rename__ *handle* *from* *to*

    This command renames the file *from* in the current directory of the ftp
    server to the specified new file name *to*\. This new file name must not be
    the same as any existing subdirectory or file name\. The command returns 1 if
    the specified file was successfully renamed or 0 if it failed\.

  - <a name='12'></a>__::ftp::Put__ *handle* \(*local* &#124; \-data *data* &#124; \-channel *chan*\) ?*remote*?

    This command transfers a local file *local* to a remote file *remote* on
    the ftp server\. If the file parameters passed to the command do not fully
    qualified path names the command will use the current directory on local and
    remote host\. If the remote file name is unspecified, the server will use the
    name of the local file as the name of the remote file\. The command returns 1
    to indicate a successful transfer and 0 in the case of a failure\.

    If __\-data__ *data* is specified instead of a local file, the system
    will not transfer a file, but the *data* passed into it\. In this case the
    name of the remote file has to be specified\.

    If __\-channel__ *chan* is specified instead of a local file, the
    system will not transfer a file, but read the contents of the channel
    *chan* and write this to the remote file\. In this case the name of the
    remote file has to be specified\. After the transfer *chan* will be closed\.

  - <a name='13'></a>__::ftp::Append__ *handle* \(*local* &#124; \-data *data* &#124; \-channel *chan*\) ?*remote*?

    This command behaves like __::ftp::Puts__, but appends the transfered
    information to the remote file\. If the file did not exist on the server it
    will be created\.

  - <a name='14'></a>__::ftp::Get__ *handle* *remote* ?\(*local* &#124; \-variable *varname* &#124; \-channel *chan*\)?

    This command retrieves a remote file *remote* on the ftp server and stores
    its contents into the local file *local*\. If the file parameters passed to
    the command are not fully qualified path names the command will use the
    current directory on local and remote host\. If the local file name is
    unspecified, the server will use the name of the remote file as the name of
    the local file\. The command returns 1 to indicate a successful transfer and
    0 in the case of a failure\. The command will throw an error if the directory
    the file *local* is to be placed in does not exist\.

    If __\-variable__ *varname* is specified, the system will store the
    retrieved data into the variable *varname* instead of a file\.

    If __\-channel__ *chan* is specified, the system will write the
    retrieved data into the channel *chan* instead of a file\. The system will
    *not* close *chan* after the transfer, this is the responsibility of the
    caller to __::ftp::Get__\.

  - <a name='15'></a>__::ftp::Reget__ *handle* *remote* ?*local*? ?*from*? ?*to*?

    This command behaves like __::ftp::Get__, except that if local file
    *local* exists and is smaller than remote file *remote*, the local file
    is presumed to be a partially transferred copy of the remote file and the
    transfer is continued from the apparent point of failure\. The command will
    throw an error if the directory the file *local* is to be placed in does
    not exist\. This command is useful when transferring very large files over
    networks that tend to drop connections\.

    Specifying the additional byte offsets *from* and *to* will cause the
    command to change its behaviour and to download exactly the specified slice
    of the remote file\. This mode is possible only if a local destination is
    explicitly provided\. Omission of *to* leads to downloading till the end of
    the file\.

  - <a name='16'></a>__::ftp::Newer__ *handle* *remote* ?*local*?

    This command behaves like __::ftp::Get__, except that it retrieves the
    remote file only if the modification time of the remote file is more recent
    than the file on the local system\. If the file does not exist on the local
    system, the remote file is considered newer\. The command will throw an error
    if the directory the file *local* is to be placed in does not exist\.

  - <a name='17'></a>__::ftp::MkDir__ *handle* *directory*

    This command creates the specified *directory* on the ftp server\. If the
    specified path is relative the new directory will be created as a
    subdirectory of the current working directory\. Else the created directory
    will have the specified path name\. The command returns 1 to indicate a
    successful creation of the directory and 0 in the case of a failure\.

  - <a name='18'></a>__::ftp::RmDir__ *handle* *directory*

    This command removes the specified directory on the ftp server\. The remote
    directory has to be empty or the command will fail\. The command returns 1 to
    indicate a successful removal of the directory and 0 in the case of a
    failure\.

  - <a name='19'></a>__::ftp::Quote__ *handle* *arg1* *arg2* *\.\.\.*

    This command is used to send an arbitrary ftp command to the server\. It
    cannot be used to obtain a directory listing or for transferring files\. It
    is included to allow an application to execute commands on the ftp server
    which are not provided by this package\. The arguments are sent verbatim,
    i\.e\. as is, with no changes\.

    In contrast to the other commands in this package this command will not
    parse the response it got from the ftp server but return it verbatim to the
    caller\.

  - <a name='20'></a>__::ftp::DisplayMsg__ *handle* *msg* ?*state*?

    This command is used by the package itself to show the different messages
    from the ftp sessions\. The package itself declares this command very simple,
    writing the messages to __stdout__ \(if __::ftp::VERBOSE__ was set,
    see below\) and throwing tcl errors for error messages\. It is the
    responsibility of the application to overwrite it as needed\. A state
    variable for different states assigned to different colors is recommended by
    the author\. The package __[log](\.\./log/log\.md)__ is useful for this\.

  - __::ftp::VERBOSE__

    A state variable controlling the output of the package\. Setting
    __::ftp::VERBOSE__ to "1" forces the package to show all responses from
    a remote server\. The default value is "0"\.

  - __::ftp::DEBUG__

    A state variable controlling the output of ftp\. Setting __::ftp::DEBUG__
    to "1" enables debugging and forces the package to show all return codes,
    states, state changes and "real" ftp commands\. The default value is "0"\.

# <a name='section3'></a>BUGS

The correct execution of many commands depends upon the proper behavior by the
remote server, network and router configuration\.

An update command placed in the procedure __::ftp::DisplayMsg__ may run into
persistent errors or infinite loops\. The solution to this problem is to use
__update idletasks__ instead of
__[update](\.\./\.\./\.\./\.\./index\.md\#update)__\.

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *ftp* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[ftpd](\.\./ftpd/ftpd\.md), [mime](\.\./mime/mime\.md),
[pop3](\.\./pop3/pop3\.md), [smtp](\.\./mime/smtp\.md)

# <a name='keywords'></a>KEYWORDS

[ftp](\.\./\.\./\.\./\.\./index\.md\#ftp),
[internet](\.\./\.\./\.\./\.\./index\.md\#internet),
[net](\.\./\.\./\.\./\.\./index\.md\#net), [rfc 959](\.\./\.\./\.\./\.\./index\.md\#rfc\_959)

# <a name='category'></a>CATEGORY

Networking
