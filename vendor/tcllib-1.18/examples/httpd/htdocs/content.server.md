http::content
=============
Back to: [Index](index.md) | [Package httpd::content](content.md)


## Class: httpd::server::dispatch

The **httpd::server::dispatch** adds additional functionality to the basic
**httpd::server** class. It's *dispatch* method performs a pattern search
based on url's registered via the *add_uri* method. That *add_uri* method
allows the developer to specify which class will handle replies, as well as
pass configuration information onto those objects.

### Option doc_root

Specifiying a *doc_root* will introduce a pattern search of last resort to
find a matching URI as a file subordinate to the *doc_root*. Also, if the
*doc_root* is specified, the system will search the root folder for the following
templates:

* notfound.tml - A site specific "404 File not found" template
* internal_error.tml - A site specific "505 Internal Server Error" template

### Method add_uri *pattern* *info*

*add_uri* appends a new pattern to the server's internal pattern search dict.
Patterns utilize **string match**, so any global characters or patterns for
string match will work.

Patterns are matched in the order in which they were given. In the example:

<pre><code>SERVER add_uri /home* {...}
SERVER add_uri /home/star/runner* {...}</code></pre>

The pattern for /home/star/runner* will never be reached because /home* was specified first.

The **info** argument contains a dict that will be passed by the *connect* method of the
server to the *dispatch* method of the reply. Only two fields are reserved by the core of
httpd:

* class - The base class for the reply
* mixin - The class to be mixed into the new object immediately prior to invoking the object's *dispatch* method.
