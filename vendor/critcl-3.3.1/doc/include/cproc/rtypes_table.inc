[comment {
  Table of the standard result types, for a quick overview
  of the names, associated C types, behaviour and limits.
}]
[example_begin]
CriTcl type    | C type         | Tcl type  | Notes
-------------- | -------------- | --------- | ------------------------------
void           | n/a            | n/a       | Always OK. Body sets result
ok             | int            | n/a       | Result code. Body sets result
-------------- | -------------- | --------- | ------------------------------
int            | int            | Int       |
boolean        |                |           | Alias of [type int] above
bool           |                |           | Alias of [type int] above
long           | long           | Long      |
wideint        | Tcl_WideInt    | WideInt   |
double         | double         | Double    |
float          | float          | Double    |
-------------- | -------------- | --------- | ------------------------------
char*          | char*          | String    | [strong {Makes a copy}]
vstring        |                |           | Alias of [type char*] above
const char*    | const char*    |           | Behavior of [type char*] above
-------------- | -------------- | --------- | ------------------------------
string         |                | String    | Freeable string set directly
               |                |           | [strong {No copy is made}]
dstring        |                |           | Alias of [type string] above
-------------- | -------------- | --------- | ------------------------------
               |                |           | For all below: Null is ERROR
               |                |           | Body has to set any message
Tcl_Obj*       | Tcl_Obj*       | Any       | [strong {refcount --}]
object         |                |           | Alias of [type Tcl_Obj*] above
Tcl_Obj*0      |                | Any       | [strong {refcount unchanged}]
object0        |                |           | Alias of [type Tcl_Obj*0] above
-------------- | -------------- | --------- | ------------------------------
known-channel  | Tcl_Channel    | String    | Assumes to already be registered
new-channel    | Tcl_Channel    | String    | New channel, will be registered
return-channel | Tcl_Channel    | String    | Inversion of take-channel
[example_end]
