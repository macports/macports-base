### Method Url_Decode *data*

Translates a standard http query encoding string into a stream of key/value pairs.

### Method FormData

For GET requests, this method will convert the Query portion of the URI (after the ?)
to key/value pairs.

For POST requests, this method will read the body of the request and convert
that block of text to a stream of key/value pairs.

### Method PostData

Returns the raw block of data from the post headers section of the transaction, up to
the Content-Length specified in the headers.