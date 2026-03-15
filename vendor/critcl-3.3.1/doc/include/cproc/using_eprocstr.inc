[subsection {More Builtin Types: Strings}]

[para] Given that "Everything is a String" is a slogan of Tcl the ability of [cmd cproc]s
to receive strings as arguments, and return them as results is quite important.

[para] We actually have a variety of builtin string types, all alike, yet different.

[para] For arguments we have:

[example_begin]
CriTcl type | C type         | Tcl type  | Notes
----------- | -------------- | --------- | ------------------------------
char*       | const char*    | Any       | [strong Read-only], [strong {string rep}]
pstring     | critcl_pstring | Any       | [strong Read-only]
bytes       | critcl_bytes   | ByteArray | [strong Read-only]
[example_end]

In C

[example {
    critcl::cproc takeStrings {
        char*   cstring
	pstring pstring
	bytes   barray
    } void {
        printf ("len %d = %s\n", strlen(cstring), cstring);
	printf ("len %d = %s\n", pstring.len, pstring.s);
	printf ("len %d = %s\n", barray.len, barray.s);
        return; // void result, no result
    }
}]

Notable about the above:

[list_begin enumerated]

[enum] The [var cstring] is a plain [type {const char*}]. It [strong {points directly}]
into the [type Tcl_Obj*] holding the argument in the script.

[enum] The [var pstring] is a slight extension to that. The value is actually a structure
containing the string pointer like [var cstring] (field [const .s]), the length of the
string (field [const .len]), and a pointer to the [type Tcl_Obj*] these came from.

[enum] The last, [var barray] is like [var pstring], however it has ensured that the
[type Tcl_Obj*] is a Tcl ByteArray, i.e. binary data.

[list_end]

[para] Treat all of them as [strong {Read Only}]. Do not modify ever.

[para] On the other side, string results, we have:

[example_begin]
CriTcl type   | C type         | Tcl type  | Notes
------------- | -------------- | --------- | ------------------------------
char*         | char*          | String    | [strong {Makes a copy}]
vstring       |                |           | Alias of [type char*] above
const char*   | const char*    |           | Behavior of [type char*] above
------------- | -------------- | --------- | ------------------------------
string        | char*          | String    | Freeable string set directly
              |                |           | [strong {No copy is made}]
dstring       |                |           | Alias of [type string] above
[example_end]

[example {
    critcl::cproc returnCString {} char* {
        return "a string";
    }
    critcl::cproc returnString {} string {
        char* str = Tcl_Alloc (200);
	sprintf (str, "hello world");
        return str; 
    }
}]

Notable about the above:

[list_begin enumerated]

[enum] The type [type char*] is best used for static strings, or strings in some kind
fixed buffer.

[para] CriTcl's translation layer makes a copy of it for the result of the command. While
it is possible to return heap-allocated strings it is the C code who is responsible for
freeing such at some point. If that is not done they will leak.

[enum] The type [type string] on the other hand is exactly for returning strings allocated
with [fun Tcl_Alloc] and associates.

[para] For these the translation layer makes no copy at all, and sets them directly as the
result of the command. A [strong {very important effect}] of this is that the ownership of
the string pointer moves from the function to Tcl.

[para] [strong Tcl] will release the allocated memory when it does not need it any
longer. The C code has no say in that.

[list_end]

