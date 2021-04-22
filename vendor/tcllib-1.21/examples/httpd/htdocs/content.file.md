httpd::content::file
====================
Back to: [Index](index.md) | [Package httpd::content](content.md)

The **httpd::content::file** class implements a system for sharing a
local file structure via http.

## Special file handling

### Directories

When a directory path is requested, the system searches for one of the following (in order):

* index.tml
* index.md
* index.html

If one of these files is found, it is delivered as the response to the request. If no index file
was found, the object will call the object's *DirectoryListing* method to
deliver a dynamic listing of the files in the directory.

### .md files

Files with the .md extension are parsed using the *Markdown* package.

### .tml files

Files with the .tml extension are parsed using a call to *subst*.
This allows them to deliver content in the same manner as tclhttpd. The
contents of the *query_headers* are loaded as local variables prior to
the *subst* call. NOTE: Unlike Tclhttpd, the substitution is performed
inside of the reply object's namespace, not the local interpreter. Thus,
template files can exercise the object's methods using the "my" command.

## Dispatch Parameters

Objects of this class needs additional information from the server in
order to operate. These fields should be coded into the **add_root** call.

### path *filepath*

The **path** parameter specifies the root of the file path to be exposed.

## Methods

### DirectoryListing *local_file*

Generates an HTML listing of a file path. The default implementation is a *very*
rudimentary **glob --nocomplain [file join $local_path \*]**

### FileName

Converts the **REQUEST_URI** from query_headers into a local file path. This
method searches first for the file name verbatim. If not found, it then searches
for the same file name with a .md, .html, or .tml extension (in that order.)
