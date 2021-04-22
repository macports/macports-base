
[//000000001]: # (tepam::argument\_dialogbox \- Tcl's Enhanced Procedure and Argument Manager)
[//000000002]: # (Generated from file 'tepam\_argument\_dialogbox\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009\-2013, Andreas Drollinger)
[//000000004]: # (tepam::argument\_dialogbox\(n\) 0\.5\.0 tcllib "Tcl's Enhanced Procedure and Argument Manager")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

tepam::argument\_dialogbox \- TEPAM argument\_dialogbox, reference manual

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [ARGUMENT DIALOGBOX CALL](#section2)

      - [Context Definition Items](#subsection1)

      - [Formatting and Display Options](#subsection2)

      - [Global Custom Data Validation](#subsection3)

      - [Data Entry Widget Items](#subsection4)

      - [Entry Widget Item Attributes](#subsection5)

  - [APPLICATION SPECIFIC ENTRY WIDGETS](#section3)

  - [VARIABLES](#section4)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.3  
package require Tk 8\.3  
package require tepam ?0\.5?  

[__tepam::argument\_dialogbox__ *item\_name item\_attributes ?item\_name item\_attributes? ?\.\.\.?*](#1)  
[__tepam::argument\_dialogbox__ \{*item\_name item\_attributes ?item\_name item\_attributes? ?\.\.\.?*\}](#2)  

# <a name='description'></a>DESCRIPTION

# <a name='section2'></a>ARGUMENT DIALOGBOX CALL

The TEPAM __argument\_dialogbox__ is a flexible and easily usable data entry
form generator that is available if Tk has been loaded\. Each data entry element
of a form is defined via a *data entry item* that can be provided to
__argument\_dialogbox__ in two formats:

  - <a name='1'></a>__tepam::argument\_dialogbox__ *item\_name item\_attributes ?item\_name item\_attributes? ?\.\.\.?*

    Using this first format, each *data entry item* is defined via a pair of
    two arguments\. The first one is the *item name* that defines the entry
    widget that has to be used in the form\. The second argument, called *item
    attributes*, specifies the variable which is attributed to the data entry
    element as well as eventual formatting and context information\.

    The __argument\_dialogbox__ returns __ok__ if the entered data have
    been acknowledged \(via the *OK* button\) and validated by a data checker\.
    If the entered data have been rejected \(via the *Cancel* button\) the
    __argument\_dialogbox__ returns __cancel__\.

    A small example illustrates how the __argument\_dialogbox__ can be
    employed:

    > set DialogResult \[__tepam::argument\_dialogbox__ \\  
    > &nbsp;&nbsp;&nbsp;__\-title__ "Itinerary selection" \\  
    > &nbsp;&nbsp;&nbsp;__\-file__ \{*\-label "Itinerary report" \-variable report\_file*\} \\  
    > &nbsp;&nbsp;&nbsp;__\-frame__ \{*\-label "Itinerary start"*\} \\  
    > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\-comment__ \{*\-text "Specify your itinerary start location"*\} \\  
    > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\-entry__ \{*\-label "City" \-variable start\_city \-type string*\} \\  
    > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\-entry__ \{*\-label "Street" \-variable start\_street \-type string \-optional 1*\} \\  
    > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\-entry__ \{*\-label "Street number" \-variable start\_street\_nbr \-type integer \-optional 1*\} \\  
    > &nbsp;&nbsp;&nbsp;__\-frame__ \{*\-label "Itinerary destination"*\} \\  
    > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\-comment__ \{*\-text "Specify your itinerary destination"*\} \\  
    > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\-entry__ \{*\-label "City" \-variable dest\_city \-type string*\} \\  
    > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\-entry__ \{*\-label "Street" \-variable dest\_street \-type string \-optional 1*\} \\  
    > &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\-entry__ \{*\-label "Street number" \-variable dest\_street\_nbr \-type integer \-optional 1*\} \\  
    > &nbsp;&nbsp;&nbsp;__\-frame__ \{\} \\  
    > &nbsp;&nbsp;&nbsp;__\-checkbutton__ \{*\-label "Don't use highways" \-variable no\_highway*\}\]

    This example opens a dialog box that has the title *Itinerary selection*\.
    A first entry widget in this box allows selecting a report file\. It follows
    two frames to define respectively an itinerary start and end location\. Each
    of these locations that are described with a comment has three entry widgets
    to specify respectively the city, street and the street number\. Bellow the
    second frame there is a check button that allows specifying if eventual
    highways should be ignored\.

  - <a name='2'></a>__tepam::argument\_dialogbox__ \{*item\_name item\_attributes ?item\_name item\_attributes? ?\.\.\.?*\}

    Sometimes it is simpler to provide all the data entry item definitions in
    form of a single list to __argument\_dialogbox__, and not as individual
    arguments\. The second format that is supported by __argument\_dialogbox__
    corresponds exactly to the first one, except that all item definitions are
    packed into a single list that is provided to __argument\_dialogbox__\.
    The previous example can therefore also be written in the following way:

    > set DialogResult \[__tepam::argument\_dialogbox \{__  
    > &nbsp;&nbsp;&nbsp;__\-title__ "Itinerary selection"  
    > &nbsp;&nbsp;&nbsp;__\-file__ \{*\-label "Itinerary report" \-variable report\_file*\}  
    > &nbsp;&nbsp;&nbsp;\.\.\.  
    > &nbsp;&nbsp;&nbsp;__\-checkbutton__ \{*\-label "Don't use highways" \-variable no\_highway*\} __\}__\]

The commands __argument\_dialogbox__ as well as
__[procedure](\.\./\.\./\.\./\.\./index\.md\#procedure)__ are exported from the
namespace __tepam__\. To use these commands without the __tepam::__
namespace prefix, it is sufficient to import them into the main namespace:

> __namespace import tepam::\*__  
>   
> set DialogResult \[__argument\_dialogbox__ \\  
> &nbsp;&nbsp;&nbsp;\-title "Itinerary selection"  
> &nbsp;&nbsp;&nbsp;\.\.\.

The following subsections explain the different argument item types that are
accepted by the __argument\_dialogbox__, classified into three groups\. The
first data entry item definition format will be used in the remaining document,
knowing that this format can always be transformed into the second format by
putting all arguments into a single list that is then provided to
__argument\_dialogbox__\.

## <a name='subsection1'></a>Context Definition Items

The first item group allows specifying some context aspects of an argument
dialog box\. These items are taking a simple character string as item attribute:

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;__\-<argument\_name>__ *string* \\  
> &nbsp;&nbsp;&nbsp;\.\.\.

The following items are classified into this group:

  - \-title *string*

    The dialog box window title which is by default *Dialog* can be changed
    with the *\-title* item:

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;__\-title__ "System configuration" \\  
> &nbsp;&nbsp;&nbsp;\.\.\.

  - \-window *string*

    The argument dialog box uses by default *\.dialog* as dialog top level
    window\. This path can be changed with the *\-window* item:

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;__\-window__ \.dialog \\  
> &nbsp;&nbsp;&nbsp;\.\.\.

  - \-parent *string*

    By defining a parent window, the argument dialog box will be displayed
    beside this one\. Without explicit parent window definition, the top\-level
    window will be considered as parent window\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;__\-parent__ \.my\_appl \\  
> &nbsp;&nbsp;&nbsp;\.\.\.

  - \-context *string*

    If a context is defined the dialog box state, e\.g\. the entered data as well
    as the window size and position, is restored the next time the argument
    dialog box is called\. The assignment of a context allows saving the dialog
    box state in its context to distinguish between different usages of the
    argument dialog box\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;__\-context__ destination\_definitions \\  
> &nbsp;&nbsp;&nbsp;\.\.\.

## <a name='subsection2'></a>Formatting and Display Options

Especially for big, complex forms it becomes important that the different data
entry widgets are graphically well organized and commented to provide an
immediate and clear overview to the user\. A couple of items allow structuring
and commenting the dialog boxes\.

The items of this classification group require as item attributes a definition
list, which contains itself attribute name and value pairs:

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;\.\.\.  
> &nbsp;&nbsp;&nbsp;__\-<argument\_name>__ \{   
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*?\-<attribute\_name> <attribute\_value>?*  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*?\-<attribute\_name> <attribute\_value>?*  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*?\.\.\.?*  
>   
> &nbsp;&nbsp;&nbsp;\}  
> &nbsp;&nbsp;&nbsp;\.\.\.

The following items are classified into this group:

  - \-frame *list*

    The *\-frame* item allows packing all following entry widgets into a
    labeled frame, until a next frame item is defined or until the last entry
    widget has been defined\. It recognizes the following attributes inside the
    item attribute list:

      * \-label *string*

        An optional frame label can be specified with the *\-label* statement\.

    Example:

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;\.\.\.  
> &nbsp;&nbsp;&nbsp;__\-frame__ \{*\-label "Destination address"*\}  
> &nbsp;&nbsp;&nbsp;\.\.\.

    To close an open frame without opening a new one, an empty list has to be
    provided to the *\-frame* statement\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;\.\.\.  
> &nbsp;&nbsp;&nbsp;__\-frame__ \{\}  
> &nbsp;&nbsp;&nbsp;\.\.\.

  - \-sep \[const \{\{\}\}\]

    Entry widgets can be separated with the *\-sep* statement which doesn't
    require additional definitions\. The related definition list has to exist,
    but its content is ignored\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;\.\.\.  
> &nbsp;&nbsp;&nbsp;__\-sep__ \{\}  
> &nbsp;&nbsp;&nbsp;\.\.\.

  - \-comment *string*

    Comments and descriptions can be added with the *\-text* attribute of the
    *\-comment* item\. Please note that each entry widget itself can also
    contain a *\-text* attribute for comments and descriptions\. But the
    *\-comment* item allows for example adding a description between two
    frames\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;\.\.\.  
> &nbsp;&nbsp;&nbsp;__\-comment__ \{*\-text "Specify bellow the destination address"*\}  
> &nbsp;&nbsp;&nbsp;\.\.\.

  - \-yscroll __0__&#124;__1__&#124;__auto__

    This attribute allows controlling an eventual vertical scrollbar\. Setting it
    to __0__ will permanently disable the scrollbar, setting it to __1__
    will enable it\. By default it is set to __auto__\. The scrollbar is
    enabled in this mode only if the vertical data entry form size exceeds 66%
    of the screen height\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;\.\.\.  
> &nbsp;&nbsp;&nbsp;__\-yscroll__ __auto__  
> &nbsp;&nbsp;&nbsp;\.\.\.

## <a name='subsection3'></a>Global Custom Data Validation

This item group allows specifying global custom checks to validate the entered
data\.

  - \-validatecommand *script*

    Custom data checks can be performed via validation commands that are defined
    with the *\-validatecommand* item\. Example:

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;\-entry \{\-label "Your comment" \-variable YourCom\} \\  
> &nbsp;&nbsp;&nbsp;__\-validatecommand__ \{IllegalWordDetector $YourCom\}

    The validation command is executed in the context of the calling procedure,
    once all the basic data checks have been performed and data variables are
    assigned\. All data is accessed via the data variables\. Note that there is
    also an entry widget specific attribute *\-validatecommand* that allows
    declaring custom checks for specific data entries\.

    The attribute *\-validatecommand* can be repeated to declare multiple
    custom checks\.

  - \-validatecommand\_error\_text *string*

    This item allows overriding the default error message for a global custom
    argument validation \(defined by *\-validatecommand*\)\. Also this attribute
    can be repeated in case multiple checks are declared\.

  - \-validatecommand2 *script*

  - \-validatecommand2\_error\_text *string*

    These items are mainly for TEPAM internal usage\.

    These items corrspond respectively to *\-validatecommand* and
    *\-validatecommand\_error\_text*\. However, the data validation is not
    performed in the next upper stack level, but two stack levels higher\.

## <a name='subsection4'></a>Data Entry Widget Items

Data entry widgets are created with the widget items\. These items require as
item attributes a definition list, which contains itself attribute name and
value pairs:

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;\.\.\.  
> &nbsp;&nbsp;&nbsp;__\-<argument\_name>__ \{   
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*?\-<attribute\_name> <attribute\_value>?*  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*?\-<attribute\_name> <attribute\_value>?*  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*?\.\.\.?*  
>   
> &nbsp;&nbsp;&nbsp;\}  
> &nbsp;&nbsp;&nbsp;\.\.\.

The attribute list can contain various attributes to describe and comment an
entry widget and to constrain its entered value\. All entry widgets are accepting
a common set of attributes that are described in the section [Entry Widget Item
Attributes](#subsection5)\.

TEPAM defines a rich set of entry widgets\. If necessary, this set can be
extended with additional application specific entry widgets \(see [APPLICATION
SPECIFIC ENTRY WIDGETS](#section3)\):

  - \-entry *list*

    The *\-entry* item generates the simplest but most universal data entry
    widget\. It allows entering any kind of data in form of single line strings\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;__\-entry__ \{\-label Name \-variable Entry\}

  - \-text *list*

    The *\-text* item generates a multi line text entry widget\. The widget
    height can be selected with the *\-height* attribute\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;__\-text__ \{\-label Name \-variable Text \-height 5\}

  - \-checkbox *list*

    A group of check boxes is created with the *\-checkbox* item\. The number of
    check boxes and their option values are specified with a list assigned to
    the *\-choices* attribute or via a variable declared with the
    *\-choicevariable* attribute:

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;__\-checkbox__ \{\-label "Font sytle" \-variable FontStyle \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-choices \{bold italic underline\} \-default italic\}

    If the labels of the check boxes should differ from the option values, their
    labels can be defined with the *\-choicelabels* attribute:

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;__\-checkbox__ \{\-label "Font sytle" \-variable FontStyle \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-choices \{bold italic underline\} \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-choicelabels \{Bold Italic Underline\} \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-default italic\}

    In contrast to a radio box group, a check box group allows selecting
    simultaneously several choice options\. The selection is stored for this
    reason inside the defined variable in form of a list, even if only one
    choice option has been selected\.

  - \-radiobox *list*

    A group of radio boxes is created with the *\-radiobox* item\. The number of
    radio boxes and their option values are specified with a list assigned to
    the *\-choices* attribute or via a variable declared with the
    *\-choicevariable* attribute\.

    In contrast to a check box group, a radio box group allows selecting
    simultaneously only one choice option\. The selected option value is stored
    directly, and not in form of a list, inside the defined variable\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;__\-radiobox__ \{\-label "Text adjustment" \-variable Adjustment \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-choices \{left center right\} \-default left\}

    If the labels of the radio boxes should differ from the option values, their
    labels can be defined with the *\-choicelabels* attribute:

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;__\-radiobox__ \{\-label "Text adjustment" \-variable Adjustment \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-choices \{left center right\} \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-choicelabels \{Left Center Right\} \-default left\}

  - \-checkbutton *list*

    The *\-checkbutton* entry widget allows activating or deactivating a single
    choice option\. The result written into the variable will either be __0__
    if the check button was not activated or __1__ if it was activated\. An
    eventually provided default value has also to be either __0__ or
    __1__\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;__\-checkbutton__ \{\-label Capitalize \-variable Capitalize \-default 1\}

Several types of list and combo boxes are available to handle selection lists\.

  - \-combobox *list*

    The combobox is a combination of a normal entry widget together with a
    drop\-down list box\. The combobox allows selecting from this drop\-down list
    box a single element\. The list of the available elements can be provided
    either as a list to the *\-choices* attribute, or via a variable that is
    specified with the *\-choicevariable* attribute\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;__\-combobox__ \{\-label "Text size" \-variable Size \-choices \{8 9 10 12 15 18\} \-default 12\}

    And here is an example of using a variable to define the selection list:

> set TextSizes \{8 9 10 12 15 18\}  
> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;__\-combobox__ \{\-label "Text size" \-variable Size \-choicevariable TextSizes \-default 12\}

  - \-listbox *list*

    In contrast to the combo box, the list box is always displayed by the
    *listbox* entry widget\. Only one element is selectable unless the
    *\-multiple\_selection* attribute is set\. The list box height can be
    selected with the *\-height* attribute\. If the height is not explicitly
    defined, the list box height is automatically adapted to the argument dialog
    box size\. The first example uses a variable to define the available choices:

> set set AvailableSizes  
> for \{set k 0\} \{$k<16\} \{incr k\} \{lappend AvailableSizes \[expr 1<<$k\]\}  
>   
> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;__\-listbox__ \{\-label "Distance" \-variable Distance \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-choicevariable AvailableSizes \-default 6 \-height 5\}

    Here is a multi\-element selection example\. Please note that also the default
    selection can contain multiple elements:

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;__\-listbox__ \{\-label "Text styles" \-variable Styles \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-choices \{bold italic underline overstrike\} \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-choicelabels \{Bold Italic Underline Overstrike\} \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-default \{bold underline\} \-multiple\_selection 1 \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-height 3\}

  - \-disjointlistbox *list*

    A disjoint list box has to be used instead of a normal list box if the
    selection order is important\. The disjoint list box entry widget has in fact
    two list boxes, one to select elements and one to display the selected
    elements in the chosen order\.

    Disjoint listboxes allow always selecting multiple elements\. With the
    exception of the *\-multiple\_selection* attribute, disjointed list boxes
    are accepting the same attributes as the normal listbox, e\.g\. *\-height,
    \-choices, \-choicevariable, \-default*\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;__\-disjointlistbox__ \{\-label "Preferred scripting languages" \-variable Languages \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-comment "Please select your preferred languages in the order" \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-choices \{JavaScript Lisp Lua Octave PHP Perl Python Ruby Scheme Tcl\} \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-default \{Tcl Perl Python\}\}

The file and directory selectors are building a next group of data entry
widgets\. A paragraph of section [Entry Widget Item
Attributes](#subsection5) explains the widget specific attributes that allow
specifying the targeted file types, active directory etc\.

  - \-file *list*

    The item *\-file* creates a group composed by an entry widget together with
    a button that allows opening a file browser\. The data type *file* is
    automatically selected for this entry if no data type has been explicitly
    defined with the *\-type* attribute\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;__\-file__ \{\-label "Image file" \-variable ImageF \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-filetypes \{\{"GIF" \{\*\.gif\}\} \{"JPG" \{\*\.jpg\}\}\} \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-initialfile "picture\.gif"\}

  - \-existingfile *list*

    The item *\-existingfile* creates a group composed by an entry widget
    together with a button that allows opening a browser to select an existing
    file\. The data type *existingfile* is automatically selected for this
    entry if no data type has been explicitly defined with the *\-type*
    attribute\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;__\-existingfile__ \{\-label "Image file" \-variable ImageF \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-filetypes \{\{"GIF" \{\*\.gif\}\} \{"JPG" \{\*\.jpg\}\}\} \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-initialfile "picture\.gif"\}

  - \-directory *list*

    The item *\-directory* creates a group composed by an entry widget together
    with a button that allows opening a directory browser\. The data type
    *directory* is automatically selected for this entry if no data type has
    been explicitly defined with the *\-type* attribute\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;__\-directory__ \{\-label "Report directory" \-variable ReportDir\}

  - \-existingdirectory *list*

    The item *\-existingdirectory* creates a group composed by an entry widget
    together with a button that allows opening a browser to select an existing
    directory\. The data type *existingdirectory* is automatically selected for
    this entry if no data type has been explicitly defined with the *\-type*
    attribute\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;__\-existingdirectory__ \{\-label "Report directory" \-variable ReportDir\}

Finally, there is a last group of some other special data entry widgets\.

  - \-color *list*

    The color selector is composed by an entry widget together with a button
    that allows opening a color browser\. The data type *color* is
    automatically selected for this entry widget type if no data type has been
    explicitly defined with the *\-type* attribute\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;__\-color__ \{\-label "Background color" \-variable Color \-default red\}

  - \-font *list*

    The font selector is composed by an entry widget together with a button that
    allows opening a font browser\. The data type *font* is automatically
    selected for this entry widget type if no data type has been explicitly
    defined with the *\-type* attribute\. The entry widget displays an example
    text in the format of the selected font\.

    The font browser allows selecting by default the font families provided by
    the __font families__ Tk command as well as a reasonable set of
    different font sizes between 6 points and 40 points\. Different sets of font
    families and font sizes can be specified respectively via the
    *\-font\_families* or *\-font\_sizes* attributes\.

    If no default font is provided via the *\-default* attribute, the default
    font of the label widget to display the selected font will be used as
    default selected font\. If the font family of this label widget is not part
    of the available families the first available family is used as default\. If
    the font size of this label widget is not part of the available sizes the
    next close available size is selected as default size\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;__\-font__ \{\-label "Font" \-variable Font \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-font\_sizes \{8 10 12 16\} \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-default \{Arial 20 italic\}\}

## <a name='subsection5'></a>Entry Widget Item Attributes

All the entry widget items are accepting the following attributes:

  - \-text *string*

    Eventual descriptions and comments specified with the *\-text* attribute
    are displayed above the entry widget\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;\-entry \{__\-text "Please enter your name bellow"__ \-variable Name\}

  - \-label *string*

    The label attribute creates left to the entry widget a label using the
    provided string as label text:

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;\-entry \{__\-label Name__ \-variable Name\}

  - \-variable *string*

    All entry widgets require a specified variable\. After accepting the entered
    information with the OK button, the entry widget data is stored inside the
    defined variables\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;\-existingdirectory \{\-label "Report directory" __\-variable ReportDir__\}

  - \-default *string*

    Eventual default data for the entry widgets can be provided via the
    *\-default* attribute\. The default value is overridden if an argument
    dialog box with a defined context is called another time\. The value
    acknowledged in a previous call will be used in this case as default value\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;\-checkbox \{\-label "Font sytle" \-variable FontStyle \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-choices \{bold italic underline\} __\-default italic__\}

  - \-optional __0__&#124;__1__

    Data can be specified as optional or mandatory with the *\-optional*
    attribute that requires either __0__ \(mandatory\) or __1__ \(optional\)
    as attribute data\.

    In case an entry is optional and no data has been entered, e\.g\. the entry
    contains an empty character string, the entry will be considered as
    undefined and the assigned variable will not be defined\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;\-entry \{\-label "City" \-variable start\_city \-type string\} \\  
> &nbsp;&nbsp;&nbsp;\-entry \{\-label "Street" \-variable start\_street \-type string __\-optional 0__\} \\  
> &nbsp;&nbsp;&nbsp;\-entry \{\-label "Street number" \-variable start\_street\_nbr \-type integer __\-optional 1__\} \\

  - \-type *string*

    If the data type is defined with the *\-type* attribute the argument dialog
    box will automatically perform a data type check after acknowledging the
    entered values and before the dialog box is closed\. If a type incompatible
    value is found an error message box appears and the user can correct the
    value\.

    The argument dialog box accepts all types that have been specified by the
    TEPAM package and that are also used by
    __[tepam::procedure](tepam\_procedure\.md)__ \(see the
    *tepam::procedure reference manual*\)\.

    Some entry widgets like the file and directory widgets, as well as the color
    and font widgets are specifying automatically the default data type if no
    type has been specified explicitly with the *\-type* attribute\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;__\-entry__ \{\-label "Street number" \-variable start\_street\_nbr __\-type integer__\} \\

  - \-range *string*

    Values can be constrained with the *\-range* attribute\. The valid range is
    defined with a list containing the minimum valid value and a maximum valid
    value\.

    The *\-range* attribute has to be used only for numerical arguments, like
    integers and doubles\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;\-entry \{\-label Month \-variable Month \-type integer __\-range \{1 12\}__\}

  - \-validatecommand *string*

    Custom argument value validations can be performed via specific validation
    commands that are defined with the *\-validatecommand* attribute\. The
    provided validation command can be a complete script in which the pattern
    *%P* is placeholder for the argument value that has to be validated\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;\-entry \{\-label "Your comment" \-variable YourCom \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\-validatecommand__ "IllegalWordDetector %P"\}

    While the purpose of this custom argument validation attribute is the
    validation of a specific argument, there is also a global data validation
    attribute *\-validatecommand* that allows performing validation that
    involves multiple arguments\.

  - \-validatecommand\_error\_text *string*

    This attribute allows overriding the default error message for a custom
    argument validation \(defined by *\-validatecommand*\)\.

Some other attributes are supported by the list and combo boxes as well as by
the radio and check buttons\.

  - \-choices *string*

    Choice lists can directly be defined with the *\-choices* attribute\. This
    way to define choice lists is especially adapted for smaller, fixed
    selection lists\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;\-listbox \{\-label "Text styles" \-variable Styles \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\-choices \{bold italic underline\}__ \-default underline

  - \-choicelabels *string* *\(only check and radio buttons\)*

    If the labels of the check and radio boxes should differ from the option
    values, they can be defined with the *\-choicelabels* attribute:

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;\-checkbox \{\-label "Font sytle" \-variable FontStyle \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-choices \{bold italic underline\} \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\-choicelabels \{Bold Italic Underline\}__

  - \-choicevariable *string*

    Another way to define the choice lists is using the *\-choicevariable*
    attribute\. This way to define choice lists is especially adapted for huge
    and eventually variable selection lists\.

> set TextSizes \{8 9 10 12 15 18\}  
> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;\-combobox \{\-label "Text size" \-variable Size __\-choicevariable TextSizes__\}

  - \-multiple\_selection __0__&#124;__1__

    The list box item \(__\-listbox__\) allows by default selecting only one
    list element\. By setting the *\-multiple\_selection* attribute to __1__,
    multiple elements can be selected\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;\-listbox \{\-label "Text styles" \-variable Styles \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-choices \{bold italic underline\} \-default underline \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\-multiple\_selection 1__ \-height 3\}

Some additional attributes are supported by the file and directory selection
widgets\.

  - \-filetypes *string*

    The file type attribute is used by the __\-file__ and
    __\-existingfile__ items to define the file endings that are searched by
    the file browser\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;\-file \{\-label "Image file" \-variable ImageF \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;__\-filetypes \{\{"GIF" \{\*\.gif\}\} \{"JPG" \{\*\.jpg\}\}\}__\}

  - \-initialfile *string*

    The initial file used by the file browsers of the __\-file__ and
    __\-existingfile__ widgets are by default the file defined with the
    *\-default* attribute, unless a file is specified with the *\-initialfile*
    attribute\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;\-file \{\-variable ImageF __\-initialfile "picture\.gif"__\}

  - \-activedir *string*

    The *\-activedir* attribute will override the default active search
    directory used by the file browsers of all file and directory entry widgets\.
    The default active search directory is defined by the directory of a
    specified initial file \(*\-initialfile*\) if defined, and otherwise by the
    directory of the default file/directory, specified with the *\-default*
    attribute\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;\-file "\-variable ImageF __\-activedir $pwd__"

Finally, there is a last attribute supported by some widgets:

  - \-height *string*

    All widgets containing a selection list \(__\-listbox__,
    __\-disjointlistbox__, __\-font__\) as well as the multi line
    __\-text__ widget are accepting the *\-height* attribute that defines
    the number of displayed rows of the selection lists\.

> tepam::argument\_dialogbox \\  
> &nbsp;&nbsp;&nbsp;\-listbox \{\-label "Text size" \-variable Size \\  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\-choices \{8 9 10 12 15 18\} \-default 12 __\-height 3__\}

    If the no height has been explicitly specified the height of the widget will
    be dynamically adapted to the argument dialog box size\.

# <a name='section3'></a>APPLICATION SPECIFIC ENTRY WIDGETS

An application specific entry widget can be made available to the argument
dialog box by adding a dedicated procedure to the __tepam__ namespace\. This
procedure has three arguments; the first one is the widget path, the second one
a subcommand and the third argument has various purposes:

> *proc* tepam::ad\_form\(<WidgetName>\) \{W Command \{Par ""\}\} \{  
> &nbsp;&nbsp;&nbsp;*upvar Option Option; \# if required*  
> &nbsp;&nbsp;&nbsp;*variable argument\_dialogbox; \# if required*  
> &nbsp;&nbsp;&nbsp;switch $Command \{  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"create" <CreateCommandSequence>  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"set\_choice" <SetChoiceCommandSequence>  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"set" <SetCommandv>  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"get" <GetCommandSequence>  
> &nbsp;&nbsp;&nbsp;\}  
> \}

__Argument\_dialogbox__ takes care about the *\-label* and *\-text*
attributes for all entry widgets\. For any data entry widget it creates a frame
into which the data entry widget components can be placed\. The path to this
frame is provided via the *W* argument\.

The entry widget procedure has to support 3 mandatory and an optional command
that are selected via the argument *Command*:

  - *create*

    The entry widget is called a first time with the command *create* to build
    the data entry widget\.

    The frames that are made available by __argument\_dialogbox__ for the
    entry widgets are by default only extendable in the X direction\. To make
    them also extendable in the Y direction, for example for extendable list
    boxes, the command __ad\_form\(make\_expandable\) $W__ has to be executed
    when an entry widget is built\.

  - *set\_choice*

    The entry widget procedure is only called with the *set\_choice* command if
    the *\-choices* or *\-choicevariable* has been specified\. The command is
    therefore only relevant for list and combo boxes\.

    The available selection list that is either specified with the *\-choices*
    or *\-choicevariable* attribute is provided via the *Par* argument to the
    entry widget procedure\. This list can be used to initialize an available
    choice list\.

  - *set*

    If a default value is either defined via the *\-default* attribute or via a
    preceding call the entry widget procedure is called with the *set*
    command\. The argument *Par* contains in this case the value to which the
    entry widget has to be initialized\.

  - *get*

    The entry widget procedure command *get* has to return the current value
    of the entry widget\.

Eventually specified entry widget item attributes are available via the
__Option__ array variable of the calling procedure\. This variable becomes
accessible inside the entry widget procedure via the __upvar__ command\.

There may be a need to store some information in a variable\. The array variable
__argument\_dialogbox__ has to be used for this purpose together with array
indexes starting with *"$W,"*, e\.g\. *argument\_dialogbox\($W,values\)*\.

Examples of entry widget procedures are directly provided by the TEPAM package
source file that specifies the standard entry widget procedures\. The simplest
procedure is the one for the basic *entry* widget:

    proc tepam::ad_form(entry) {W Command {Par ""}} {
       switch $Command {
          "create" {pack [entry \$W.entry] -fill x \
                            -expand yes -pady 4 -side left}
          "set" {\$W.entry insert 0 $Par}
          "get" {return [\$W.entry get]}
       }
    }

It is also possible to relay on an existing entry widget procedure to derive a
new, more specific one\. The *radiobox* widget is used for example, to create a
new entry widget that allows selecting either *left*, *center* or *right*\.
The original *radiobox* widget is called with the *set\_choice* command
immediately after the *create* command, to define the fixed list of selection
options\.

    proc tepam::ad_form(rcl) {W Command {Par ""}} {
       set Res [ad_form(radiobox) $W $Command $Par]
       if {$Command=="create"} {
          ad_form(radiobox) $W set_choice {left center right}
       }
       return $Res
    }

Please consult the TEPAM package source file to find additional and more complex
examples of entry widget procedures\.

# <a name='section4'></a>VARIABLES

The __argument\_dialogbox__ is using two variables inside the namespace
__::tepam__:

  - __argument\_dialogbox__

    Application specific entry widget procedures can use this array variable to
    store their own data, using as index the widget path provided to the
    procedure, e\.g\. *argument\_dialogbox\($W,<sub\_index>\)*\.

  - __last\_parameters__

    This array variable is only used by an argument dialog box if its context
    has been specified via the *\-context* attribute\. The argument dialog box
    position and size as well as its entered data are stored inside this
    variable if the data are acknowledged and the form is closed\. This allows
    the form to restore its previous state once it is called another time\.

    To reuse the saved parameters not just in the actual application session but
    also in another one, it is sufficient to store the __last\_parameter__
    array variable contents in a configuration file which is loaded the next
    time an application is launched\.

# <a name='seealso'></a>SEE ALSO

[tepam\(n\)](tepam\_introduction\.md),
[tepam::procedure\(n\)](tepam\_procedure\.md)

# <a name='keywords'></a>KEYWORDS

[data entry form](\.\./\.\./\.\./\.\./index\.md\#data\_entry\_form), [parameter entry
form](\.\./\.\./\.\./\.\./index\.md\#parameter\_entry\_form)

# <a name='category'></a>CATEGORY

Argument entry form, mega widget

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009\-2013, Andreas Drollinger
