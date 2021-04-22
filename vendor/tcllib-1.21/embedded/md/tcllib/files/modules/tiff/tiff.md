
[//000000001]: # (tiff \- TIFF image manipulation)
[//000000002]: # (Generated from file 'tiff\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2005\-2006, Aaron Faupell <afaupell@users\.sourceforge\.net>)
[//000000004]: # (tiff\(n\) 0\.2\.1 tcllib "TIFF image manipulation")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

tiff \- TIFF reading, writing, and querying and manipulation of meta data

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [VARIABLES](#section3)

  - [LIMITATIONS](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require tiff ?0\.2\.1?  

[__::tiff::isTIFF__ *file*](#1)  
[__::tiff::byteOrder__ *file*](#2)  
[__::tiff::numImages__ *file*](#3)  
[__::tiff::dimensions__ *file* ?image?](#4)  
[__::tiff::imageInfo__ *file* ?image?](#5)  
[__::tiff::entries__ *file* ?image?](#6)  
[__::tiff::getEntry__ *file* *entry* ?image?](#7)  
[__::tiff::addEntry__ *file* *entry* ?image?](#8)  
[__::tiff::deleteEntry__ *file* *entry* ?image?](#9)  
[__::tiff::getImage__ *file* ?image?](#10)  
[__::tiff::writeImage__ *image* *file* ?entry?](#11)  
[__::tiff::nametotag__ *names*](#12)  
[__::tiff::tagtoname__ *tags*](#13)  
[__::tiff::debug__ *file*](#14)  

# <a name='description'></a>DESCRIPTION

This package provides commands to query, modify, read, and write TIFF images\.
TIFF stands for *Tagged Image File Format* and is a standard for lossless
storage of photographical images and associated metadata\. It is specified at
[http://partners\.adobe\.com/public/developer/tiff/index\.html](http://partners\.adobe\.com/public/developer/tiff/index\.html)\.

Multiple images may be stored in a single TIFF file\. The ?image? options to the
functions in this package are for accessing images other than the first\. Data in
a TIFF image is stored as a series of tags having a numerical value, which are
represented in either a 4 digit hexadecimal format or a string name\. For a
reference on defined tags and their meanings see
[http://www\.awaresystems\.be/imaging/tiff/tifftags\.html](http://www\.awaresystems\.be/imaging/tiff/tifftags\.html)

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::tiff::isTIFF__ *file*

    Returns a boolean value indicating if *file* is a TIFF image\.

  - <a name='2'></a>__::tiff::byteOrder__ *file*

    Returns either __big__ or __little__\. Throws an error if *file* is
    not a TIFF image\.

  - <a name='3'></a>__::tiff::numImages__ *file*

    Returns the number of images in *file*\. Throws an error if *file* is not
    a TIFF image\.

  - <a name='4'></a>__::tiff::dimensions__ *file* ?image?

    Returns the dimensions of image number ?image? in *file* as a list of the
    horizontal and vertical pixel count\. Throws an error if *file* is not a
    TIFF image\.

  - <a name='5'></a>__::tiff::imageInfo__ *file* ?image?

    Returns a dictionary with keys __ImageWidth__, __ImageLength__,
    __BitsPerSample__, __Compression__,
    __PhotometricInterpretation__, __ImageDescription__,
    __Orientation__, __XResolution__, __YResolution__,
    __ResolutionUnit__, __DateTime__, __Artist__, and
    __HostComputer__\. The values are the associated properties of the TIFF
    ?image? in *file*\. Values may be empty if the associated tag is not
    present in the file\.

        puts [::tiff::imageInfo photo.tif]

        ImageWidth 686 ImageLength 1024 BitsPerSample {8 8 8} Compression 1
        PhotometricInterpretation 2 ImageDescription {} Orientation 1
        XResolution 170.667 YResolution 170.667 ResolutionUnit 2 DateTime {2005:12:28 19:44:45}
        Artist {} HostComputer {}

    There is nothing special about these tags, this is simply a convience
    procedure which calls __getEntry__ with common entries\. Throws an error
    if *file* is not a TIFF image\.

  - <a name='6'></a>__::tiff::entries__ *file* ?image?

    Returns a list of all entries in the given *file* and ?image? in
    hexadecimal format\. Throws an error if *file* is not a TIFF image\.

  - <a name='7'></a>__::tiff::getEntry__ *file* *entry* ?image?

    Returns the value of *entry* from image ?image? in the TIFF *file*\.
    *entry* may be a list of multiple entries\. If an entry does not exist, an
    empty string is returned

        set data [::tiff::getEntry photo.tif {0131 0132}]
        puts "file was written at [lindex $data 0] with software [lindex $data 1]"

    Throws an error if *file* is not a TIFF image\.

  - <a name='8'></a>__::tiff::addEntry__ *file* *entry* ?image?

    Adds the specified entries to the image named by ?image? \(default 0\), or
    optionally __all__\. *entry* must be a list where each element is a
    list of tag, type, and value\. If a tag already exists, it is overwritten\.

        ::tiff::addEntry photo.tif {{010e 2 "an example photo"} {013b 2 "Aaron F"}}

    The data types are defined as follows

      * __1__

        BYTE \(8 bit unsigned integer\)

      * __2__

        ASCII

      * __3__

        SHORT \(16 bit unsigned integer\)

      * __4__

        LONG \(32 bit unsigned integer\)

      * __5__

        RATIONAL

      * __6__

        SBYTE \(8 bit signed byte\)

      * __7__

        UNDEFINED \(uninterpreted binary data\)

      * __8__

        SSHORT \(signed 16 bit integer\)

      * __9__

        SLONG \(signed 32 bit integer\)

      * __10__

        SRATIONAL

      * __11__

        FLOAT \(32 bit floating point number\)

      * __12__

        DOUBLE \(64 bit floating point number\)

    Throws an error if *file* is not a TIFF image\.

  - <a name='9'></a>__::tiff::deleteEntry__ *file* *entry* ?image?

    Deletes the specified entries from the image named by ?image? \(default 0\),
    or optionally __all__\. Throws an error if *file* is not a TIFF image\.

  - <a name='10'></a>__::tiff::getImage__ *file* ?image?

    Returns the name of a Tk image containing the image at index ?image? from
    *file* Throws an error if *file* is not a TIFF image, or if image is an
    unsupported format\. Supported formats are uncompressed 24 bit RGB and
    uncompressed 8 bit palette\.

  - <a name='11'></a>__::tiff::writeImage__ *image* *file* ?entry?

    Writes the contents of the Tk image *image* to a tiff file *file*\. Files
    are written in the 24 bit uncompressed format, with big endian byte order\.
    Additional entries to be added to the image may be specified, in the same
    format as __tiff::addEntry__

  - <a name='12'></a>__::tiff::nametotag__ *names*

    Returns a list with *names* translated from string to 4 digit format\. 4
    digit names in the input are passed through unchanged\. Strings without a
    defined tag name will throw an error\.

  - <a name='13'></a>__::tiff::tagtoname__ *tags*

    Returns a list with *tags* translated from 4 digit to string format\. If a
    tag does not have a defined name it is passed through unchanged\.

  - <a name='14'></a>__::tiff::debug__ *file*

    Prints everything we know about the given file in a nice format\.

# <a name='section3'></a>VARIABLES

The mapping of 4 digit tag names to string names uses the array
::tiff::tiff\_tags\. The reverse mapping uses the array ::tiff::tiff\_sgat\.

# <a name='section4'></a>LIMITATIONS

  1. Cannot write exif ifd

  1. Reading limited to uncompressed 8 bit rgb and 8 bit palletized images

  1. Writing limited to uncompressed 8 bit rgb

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *tiff* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[image](\.\./\.\./\.\./\.\./index\.md\#image), [tif](\.\./\.\./\.\./\.\./index\.md\#tif),
[tiff](\.\./\.\./\.\./\.\./index\.md\#tiff)

# <a name='category'></a>CATEGORY

File formats

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2005\-2006, Aaron Faupell <afaupell@users\.sourceforge\.net>
