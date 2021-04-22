
[//000000001]: # (png \- Image manipulation)
[//000000002]: # (Generated from file 'png\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004, Code: Aaron Faupell <afaupell@users\.sourceforge\.net>)
[//000000004]: # (Copyright &copy; 2004, Doc:  Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000005]: # (png\(n\) 0\.3 tcllib "Image manipulation")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

png \- PNG querying and manipulation of meta data

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require crc32  
package require png ?0\.3?  

[__::png::validate__ *file*](#1)  
[__::png::isPNG__ *file*](#2)  
[__::png::imageInfo__ *file*](#3)  
[__::png::getTimestamp__ *file*](#4)  
[__::png::setTimestamp__ *file* *time*](#5)  
[__::png::getComments__ *file*](#6)  
[__::png::removeComments__ *file*](#7)  
[__::png::addComment__ *file* *keyword* *text*](#8)  
[__::png::addComment__ *file* *keyword* *lang* *keyword2* *text*](#9)  
[__::png::getPixelDimension__ *file*](#10)  
[__::png::image__ *file*](#11)  
[__::png::write__ *file* *data*](#12)  

# <a name='description'></a>DESCRIPTION

This package provides commands to query and modify PNG images\. PNG stands for
*Portable Network Graphics* and is specified at
[http://www\.libpng\.org/pub/png/spec/1\.2](http://www\.libpng\.org/pub/png/spec/1\.2)\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::png::validate__ *file*

    Returns a value indicating if *file* is a valid PNG file\. The file is
    checked for PNG signature, each chunks checksum is verified, existence of a
    data chunk is verified, first chunk is checked for header, last chunk is
    checked for ending\. Things *not* checked for are: validity of values
    within a chunk, multiple header chunks, noncontiguous data chunks, end chunk
    before actual eof\. This procedure can take lots of time\.

    Possible return values:

      * OK

        File is a valid PNG file\.

      * SIG

        no/broken PNG signature\.

      * BADLEN

        corrupt chunk length\.

      * EOF

        premature end of file\.

      * NOHDR

        missing header chunk\.

      * CKSUM

        crc mismatch\.

      * NODATA

        missing data chunk\(s\)\.

      * NOEND

        missing end marker\.

  - <a name='2'></a>__::png::isPNG__ *file*

    Returns a boolean value indicating if the file *file* starts with a PNG
    signature\. This is a much faster and less intensive check than
    __::png::validate__ as it does not check if the PNG data is valid\.

  - <a name='3'></a>__::png::imageInfo__ *file*

    Returns a dictionary with keys __width__, __height__, __depth__,
    __color__, __compression__, __filter__, and __interlace__\.
    The values are the associated properties of the PNG image in *file*\.
    Throws an error if file is not a PNG image, or if the checksum of the header
    is invalid\. For information on interpreting the values for the returned
    properties see
    [http://www\.libpng\.org/pub/png/spec/1\.2/PNG\-Chunks\.html](http://www\.libpng\.org/pub/png/spec/1\.2/PNG\-Chunks\.html)\.

  - <a name='4'></a>__::png::getTimestamp__ *file*

    Returns the epoch time if a timestamp chunk is found in the PNG image
    contained in the *file*, otherwise returns the empty string\. Does not
    attempt to verify the checksum of the timestamp chunk\. Throws an error if
    the *file* is not a valid PNG image\.

  - <a name='5'></a>__::png::setTimestamp__ *file* *time*

    Writes a new timestamp to the *file*, either replacing the old timestamp,
    or adding one just before the data chunks if there was no previous
    timestamp\. *time* is the new time in the gmt epoch format\. Throws an error
    if *file* is not a valid PNG image\.

  - <a name='6'></a>__::png::getComments__ *file*

    Currently supports only uncompressed comments\. Does not attempt to verify
    the checksums of the comment chunks\. Returns a list where each element is a
    comment\. Each comment is itself a list\. The list for a plain text comment
    consists of 2 elements: the human readable keyword, and the text data\. A
    unicode \(international\) comment consists of 4 elements: the human readable
    keyword, the language identifier, the translated keyword, and the unicode
    text data\. Throws an error if *file* is not a valid PNG image\.

  - <a name='7'></a>__::png::removeComments__ *file*

    Removes all comments from the PNG image in *file*\. Beware \- This uses
    memory equal to the file size minus comments, to hold the intermediate
    result\. Throws an error if *file* is not a valid PNG image\.

  - <a name='8'></a>__::png::addComment__ *file* *keyword* *text*

    Adds a plain *text* comment to the PNG image in *file*, just before the
    first data chunk\. Will throw an error if no data chunk is found\. *keyword*
    has to be less than 80 characters long to conform to the PNG specification\.

  - <a name='9'></a>__::png::addComment__ *file* *keyword* *lang* *keyword2* *text*

    Adds a unicode \(international\) comment to the PNG image in *file*, just
    before the first data chunk\. Will throw an error if no data chunk is found\.
    *keyword* has to be less than 80 characters long to conform to the PNG
    specification\. *keyword2* is the translated *keyword*, in the language
    specified by the language identifier *lang*\.

  - <a name='10'></a>__::png::getPixelDimension__ *file*

    Returns a dictionary with keys __ppux__, __ppuy__ and __unit__
    if the information is present\. Otherwise, it returns the empty string\.

    The values of __ppux__ and __ppuy__ return the pixel per unit value
    in X or Y direction\.

    The allowed values for key __unit__ are __meter__ and
    __unknown__\. In the case of meter, the dpi value can be calculated by
    multiplying with the conversion factor __0\.0254__\.

  - <a name='11'></a>__::png::image__ *file*

    Given a PNG file returns the image in the list of scanlines format used by
    Tk\_GetColor\.

  - <a name='12'></a>__::png::write__ *file* *data*

    Takes a list of scanlines in the Tk\_GetColor format and writes the
    represented image to *file*\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *png* of the [Tcllib
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
[image](\.\./\.\./\.\./\.\./index\.md\#image), [png](\.\./\.\./\.\./\.\./index\.md\#png),
[timestamp](\.\./\.\./\.\./\.\./index\.md\#timestamp)

# <a name='category'></a>CATEGORY

File formats

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2004, Code: Aaron Faupell <afaupell@users\.sourceforge\.net>  
Copyright &copy; 2004, Doc:  Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
