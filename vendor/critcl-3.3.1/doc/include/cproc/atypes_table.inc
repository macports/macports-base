[comment {
  Table of the standard argument types, for a quick overview
  of the names, associated C types, behaviour and limits.
}]
[example_begin]
CriTcl type      | C type         | Tcl type  | Notes
---------------- | -------------- | --------- | ------------------------------
Tcl_Interp*      | Tcl_Interp*    | n/a       | [strong Special], only first
---------------- | -------------- | --------- | ------------------------------
Tcl_Obj*         | Tcl_Obj*       | Any       | [strong Read-only]
object           |                |           | Alias of [type Tcl_Obj*] above
list             | critcl_list    | List      | [strong Read-only]
[lb][rb], [lb]*[rb]          |                |           | Alias of [type list] above
---------------- | -------------- | --------- | ------------------------------
[lb]N[rb]              |                |           | Restricted [type list]-types.
type[lb][rb], type[lb]N[rb]  |                |           | Length-limited ([lb]..[rb]), expected
[lb][rb]type, [lb]N[rb]type  |                |           | element type, or both.
                 |                |           |
                 |                |           | Element types can be all known argument
                 |                |           | types, except for any kind of list.
                 |                |           | IOW multi-dimensional lists are not
                 |                |           | supported.
---------------- | -------------- | --------- | ------------------------------
char*            | const char*    | Any       | [strong Read-only], [strong {string rep}]
pstring          | critcl_pstring | Any       | [strong Read-only]
bytes            | critcl_bytes   | ByteArray | [strong Read-only]
---------------- | -------------- | --------- | ------------------------------
int              | int            | Int       |
long             | long           | Long      |
wideint          | Tcl_WideInt    | WideInt   |
double           | double         | Double    |
float            | float          | Double    |
---------------- | -------------- | --------- | ------------------------------
X > N            |                |           | For X in [type int] ... [type float] above.
X >= N           |                |           | The C types are as per the base type X.
X < N            |                |           | N, A, B are expected to be constant integer
X <= N           |                |           | numbers for types [type int], [type long],
X > A < B        |                |           | and [type wideint]. For types [type double]
etc.             |                |           | and [type float] the N, A, and B can be floating
                 |                |           | point numbers. Multiple restrictions are
                 |                |           | fused as much as possible to yield at most
                 |                |           | both upper and lower limits.
---------------- | -------------- | --------- | ------------------------------
boolean          | int            | Boolean   |
bool             |                |           | Alias of [type boolean] above
---------------- | -------------- | --------- | ------------------------------
channel          | Tcl_Channel    | String    | Assumed to be registered
unshared-channel | Tcl_Channel    | String    | As above, limited to current interpreter
take-channel     | Tcl_Channel    | String    | As above, C code takes ownership
[example_end]
