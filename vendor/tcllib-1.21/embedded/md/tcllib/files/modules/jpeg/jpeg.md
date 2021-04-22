
[//000000001]: # (jpeg \- JPEG image manipulation)
[//000000002]: # (Generated from file 'jpeg\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004\-2005, Code: Aaron Faupell <afaupell@users\.sourceforge\.net>)
[//000000004]: # (Copyright &copy; 2007, Code:  Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000005]: # (Copyright &copy; 2004\-2009, Doc:  Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000006]: # (Copyright &copy; 2011, Code: Pat Thoyts <patthoyts@users\.sourceforge\.net>)
[//000000007]: # (jpeg\(n\) 0\.5 tcllib "JPEG image manipulation")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

jpeg \- JPEG querying and manipulation of meta data

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [LIMITATIONS](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require jpeg ?0\.5?  

[__::jpeg::isJPEG__ *file*](#1)  
[__::jpeg::imageInfo__ *file*](#2)  
[__::jpeg::dimensions__ *file*](#3)  
[__::jpeg::getThumbnail__ *file*](#4)  
[__::jpeg::getExif__ *file* ?*section*?](#5)  
[__::jpeg::getExifFromChannel__ *channel* ?*section*?](#6)  
[__::jpeg::formatExif__ *keys*](#7)  
[__::jpeg::exifKeys__](#8)  
[__::jpeg::removeExif__ *file*](#9)  
[__::jpeg::stripJPEG__ *file*](#10)  
[__::jpeg::getComments__ *file*](#11)  
[__::jpeg::addComment__ *file* *text*\.\.\.](#12)  
[__::jpeg::removeComments__ *file*](#13)  
[__::jpeg::replaceComment__ *file* *text*](#14)  
[__::jpeg::debug__ *file*](#15)  
[__::jpeg::markers__ *channel*](#16)  

# <a name='description'></a>DESCRIPTION

This package provides commands to query and modify JPEG images\. JPEG stands for
*Joint Photography Experts Group* and is a standard for the lossy compression
of photographical images\. It is specified at [LINK\_HERE](LINK\_HERE)\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::jpeg::isJPEG__ *file*

    Returns a boolean value indicating if *file* is a JPEG image\.

  - <a name='2'></a>__::jpeg::imageInfo__ *file*

    Returns a dictionary with keys __version__, __units__,
    __xdensity__, __ydensity__, __xthumb__, and __ythumb__\. The
    values are the associated properties of the JPEG image in *file*\. Throws
    an error if *file* is not a JPEG image\.

  - <a name='3'></a>__::jpeg::dimensions__ *file*

    Returns the dimensions of the JPEG *file* as a list of the horizontal and
    vertical pixel count\. Throws an error if *file* is not a JPEG image\.

  - <a name='4'></a>__::jpeg::getThumbnail__ *file*

    This procedure will return the binary thumbnail image data, if a JPEG
    thumbnail is included in *file*, and the empty string otherwise\. Note that
    it is possible to include thumbnails in formats other than JPEG although
    that is not common\. The command finds thumbnails that are encoded in either
    the JFXX or EXIF segments of the JPEG information\. If both are present the
    EXIF thumbnail will take precedence\. Throws an error if *file* is not a
    JPEG image\.

        set fh [open thumbnail.jpg w+]
        fconfigure $fh -translation binary -encoding binary
        puts -nonewline $fh [::jpeg::getThumbnail photo.jpg]
        close $fh

  - <a name='5'></a>__::jpeg::getExif__ *file* ?*section*?

    *section* must be one of __main__ or __thumbnail__\. The default is
    __main__\. Returns a dictionary containing the EXIF information for the
    specified section\. For example:

            set exif {
        	Make     Canon
        	Model    {Canon DIGITAL IXUS}
        	DateTime {2001:06:09 15:17:32}
            }

    Throws an error if *file* is not a JPEG image\.

  - <a name='6'></a>__::jpeg::getExifFromChannel__ *channel* ?*section*?

    This command is as per __::jpeg::getExif__ except that it uses a
    previously opened channel\. *channel* should be a seekable channel and
    *section* is as described in the documentation of __::jpeg::getExif__\.

    *Note*: The jpeg parser expects that the start of the channel is the start
    of the image data\. If working with an image embedded in a container file
    format it may be necessary to read the jpeg data into a temporary container:
    either a temporary file or a memory channel\.

    *Attention*: It is the resonsibility of the caller to close the channel
    after its use\.

  - <a name='7'></a>__::jpeg::formatExif__ *keys*

    Takes a list of key\-value pairs as returned by __getExif__ and formats
    many of the values into a more human readable form\. As few as one key\-value
    may be passed in, the entire exif is not required\.

        foreach {key val} [::jpeg::formatExif [::jpeg::getExif photo.jpg]] {
            puts "$key: $val"
        }

        array set exif [::jpeg::getExif photo.jpg]
        puts "max f-stop: [::jpeg::formatExif [list MaxAperture $exif(MaxAperture)]]

  - <a name='8'></a>__::jpeg::exifKeys__

    Returns a list of the EXIF keys which are currently understood\. There may be
    keys present in __getExif__ data that are not understood\. Those keys
    will appear in a 4 digit hexadecimal format\.

  - <a name='9'></a>__::jpeg::removeExif__ *file*

    Removes the Exif data segment from the specified file and replaces it with a
    standard JFIF segment\. Throws an error if *file* is not a JPEG image\.

  - <a name='10'></a>__::jpeg::stripJPEG__ *file*

    Removes all metadata from the JPEG file leaving only the image\. This
    includes comments, EXIF segments, JFXX segments, and application specific
    segments\. Throws an error if *file* is not a JPEG image\.

  - <a name='11'></a>__::jpeg::getComments__ *file*

    Returns a list containing all the JPEG comments found in the *file*\.
    Throws an error if *file* is not a valid JPEG image\.

  - <a name='12'></a>__::jpeg::addComment__ *file* *text*\.\.\.

    Adds one or more plain *text* comments to the JPEG image in *file*\.
    Throws an error if *file* is not a valid JPEG image\.

  - <a name='13'></a>__::jpeg::removeComments__ *file*

    Removes all comments from the file specified\. Throws an error if *file* is
    not a valid JPEG image\.

  - <a name='14'></a>__::jpeg::replaceComment__ *file* *text*

    Replaces the first comment in the file with the new *text*\. This is merely
    a shortcut for __::jpeg::removeComments__ and __::jpeg::addComment__
    Throws an error if *file* is not a valid JPEG image\.

  - <a name='15'></a>__::jpeg::debug__ *file*

    Prints everything we know about the given file in a nice format\.

  - <a name='16'></a>__::jpeg::markers__ *channel*

    This is an internal helper command, we document it for use by advanced users
    of the package\. The argument *channel* is an open file handle positioned
    at the start of the first marker \(usually 2 bytes\)\. The command returns a
    list with one element for each JFIF marker found in the file\. Each element
    consists of a list of the marker name, its offset in the file, and its
    length\. The offset points to the beginning of the sections data, not the
    marker itself\. The length is the length of the data from the offset listed
    to the start of the next marker\.

# <a name='section3'></a>LIMITATIONS

can only work with files cant write exif data gps exif data not parsed makernote
data not yet implemented

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *jpeg* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[comment](\.\./\.\./\.\./\.\./index\.md\#comment),
[exif](\.\./\.\./\.\./\.\./index\.md\#exif), [image](\.\./\.\./\.\./\.\./index\.md\#image),
[jfif](\.\./\.\./\.\./\.\./index\.md\#jfif), [jpeg](\.\./\.\./\.\./\.\./index\.md\#jpeg),
[thumbnail](\.\./\.\./\.\./\.\./index\.md\#thumbnail)

# <a name='category'></a>CATEGORY

File formats

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2004\-2005, Code: Aaron Faupell <afaupell@users\.sourceforge\.net>  
Copyright &copy; 2007, Code:  Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>  
Copyright &copy; 2004\-2009, Doc:  Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>  
Copyright &copy; 2011, Code: Pat Thoyts <patthoyts@users\.sourceforge\.net>
