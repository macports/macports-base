
[//000000001]: # (practcl \- The The Proper Rational API for C to Tool Command Language Module)
[//000000002]: # (Generated from file 'practcl\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2016\-2018 Sean Woods <yoda@etoyoc\.com>)
[//000000004]: # (practcl\(n\) 0\.16\.4 tcllib "The The Proper Rational API for C to Tool Command Language Module")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

practcl \- The Practcl Module

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Commands](#section2)

  - [Classes](#section3)

      - [Class practcl::doctool](#subsection1)

      - [Class practcl::metaclass](#subsection2)

      - [Class practcl::toolset](#subsection3)

      - [Class practcl::toolset\.gcc](#subsection4)

      - [Class practcl::toolset\.msvc](#subsection5)

      - [Class practcl::make\_obj](#subsection6)

      - [Class practcl::object](#subsection7)

      - [Class practcl::dynamic](#subsection8)

      - [Class practcl::product](#subsection9)

      - [Class practcl::product\.cheader](#subsection10)

      - [Class practcl::product\.csource](#subsection11)

      - [Class practcl::product\.clibrary](#subsection12)

      - [Class practcl::product\.dynamic](#subsection13)

      - [Class practcl::product\.critcl](#subsection14)

      - [Class practcl::module](#subsection15)

      - [Class practcl::project](#subsection16)

      - [Class practcl::library](#subsection17)

      - [Class practcl::tclkit](#subsection18)

      - [Class practcl::distribution](#subsection19)

      - [Class practcl::distribution\.snapshot](#subsection20)

      - [Class practcl::distribution\.fossil](#subsection21)

      - [Class practcl::distribution\.git](#subsection22)

      - [Class practcl::subproject](#subsection23)

      - [Class practcl::subproject\.source](#subsection24)

      - [Class practcl::subproject\.teapot](#subsection25)

      - [Class practcl::subproject\.kettle](#subsection26)

      - [Class practcl::subproject\.critcl](#subsection27)

      - [Class practcl::subproject\.sak](#subsection28)

      - [Class practcl::subproject\.practcl](#subsection29)

      - [Class practcl::subproject\.binary](#subsection30)

      - [Class practcl::subproject\.tea](#subsection31)

      - [Class practcl::subproject\.library](#subsection32)

      - [Class practcl::subproject\.external](#subsection33)

      - [Class practcl::subproject\.core](#subsection34)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require TclOO 1\.0  

[proc __practcl::cat__ *fname*](#1)  
[proc __practcl::docstrip__ *text*](#2)  
[proc __putb__ ?*map*? *text*](#3)  
[proc __[Proc](\.\./\.\./\.\./\.\./index\.md\#proc)__ *name* *arglist* *body*](#4)  
[proc __noop__ ?*args*?](#5)  
[proc __practcl::debug__ ?*args*?](#6)  
[proc __practcl::doexec__ ?*args*?](#7)  
[proc __practcl::doexec\_in__ *path* ?*args*?](#8)  
[proc __practcl::dotclexec__ ?*args*?](#9)  
[proc __practcl::domake__ *path* ?*args*?](#10)  
[proc __practcl::domake\.tcl__ *path* ?*args*?](#11)  
[proc __practcl::fossil__ *path* ?*args*?](#12)  
[proc __practcl::fossil\_status__ *dir*](#13)  
[proc __practcl::os__](#14)  
[proc __practcl::mkzip__ *exename* *barekit* *vfspath*](#15)  
[proc __practcl::sort\_dict__ *list*](#16)  
[proc __practcl::local\_os__](#17)  
[proc __practcl::config\.tcl__ *path*](#18)  
[proc __practcl::read\_configuration__ *path*](#19)  
[proc __practcl::tcllib\_require__ *pkg* ?*args*?](#20)  
[proc __practcl::platform::tcl\_core\_options__ *os*](#21)  
[proc __practcl::platform::tk\_core\_options__ *os*](#22)  
[proc __practcl::read\_rc\_file__ *filename* ?*localdat* ____?](#23)  
[proc __practcl::read\_sh\_subst__ *line* *info*](#24)  
[proc __practcl::read\_sh\_file__ *filename* ?*localdat* ____?](#25)  
[proc __practcl::read\_Config\.sh__ *filename*](#26)  
[proc __practcl::read\_Makefile__ *filename*](#27)  
[proc __practcl::cputs__ *varname* ?*args*?](#28)  
[proc __practcl::tcl\_to\_c__ *body*](#29)  
[proc __practcl::\_tagblock__ *text* ?*style* __tcl__? ?*note* ____?](#30)  
[proc __practcl::de\_shell__ *data*](#31)  
[proc __practcl::grep__ *pattern* ?*files* ____?](#32)  
[proc __practcl::file\_lexnormalize__ *sp*](#33)  
[proc __practcl::file\_relative__ *base* *dst*](#34)  
[proc __practcl::findByPattern__ *basedir* *patterns*](#35)  
[proc __practcl::log__ *fname* *comment*](#36)  
[proc __practcl::\_pkgindex\_simpleIndex__ *path*](#37)  
[proc __practcl::\_pkgindex\_directory__ *path*](#38)  
[proc __practcl::\_pkgindex\_path\_subdir__ *path*](#39)  
[proc __practcl::pkgindex\_path__ ?*args*?](#40)  
[proc __practcl::installDir__ *d1* *d2*](#41)  
[proc __practcl::copyDir__ *d1* *d2* ?*toplevel* __1__?](#42)  
[proc __practcl::buildModule__ *modpath*](#43)  
[proc __practcl::installModule__ *modpath* *DEST*](#44)  
[proc __practcl::trigger__ ?*args*?](#45)  
[proc __practcl::depends__ ?*args*?](#46)  
[proc __practcl::target__ *name* *info* ?*action* ____?](#47)  
[method __constructor__](#48)  
[method __argspec__ *argspec*](#49)  
[method __[comment](\.\./\.\./\.\./\.\./index\.md\#comment)__ *block*](#50)  
[method __keyword\.Annotation__ *resultvar* *commentblock* *type* *name* *body*](#51)  
[method __keyword\.Class__ *resultvar* *commentblock* *name* *body*](#52)  
[method __keyword\.class__ *resultvar* *commentblock* *name* *body*](#53)  
[method __keyword\.Class\_Method__ *resultvar* *commentblock* *name* ?*args*?](#54)  
[method __keyword\.method__ *resultvar* *commentblock* *name* ?*args*?](#55)  
[method __keyword\.proc__ *commentblock* *name* *argspec*](#56)  
[method __reset__](#57)  
[method __Main__](#58)  
[method __section\.method__ *keyword* *method* *minfo*](#59)  
[method __section\.annotation__ *type* *name* *iinfo*](#60)  
[method __section\.class__ *class\_name* *class\_info*](#61)  
[method __section\.command__ *procinfo*](#62)  
[method __[manpage](\.\./\.\./\.\./\.\./index\.md\#manpage)__ ?__header *value*__? ?__footer *value*__? ?__authors *list*__?](#63)  
[method __scan\_text__ *text*](#64)  
[method __scan\_file__ *filename*](#65)  
[method __\_MorphPatterns__](#66)  
[method __[define](\.\./\.\./\.\./\.\./index\.md\#define)__ *submethod* ?*args*?](#67)  
[method __graft__ ?*args*?](#68)  
[method __initialize__](#69)  
[method __link__ *command* ?*args*?](#70)  
[method __morph__ *classname*](#71)  
[method __script__ *script*](#72)  
[method __select__](#73)  
[method __[source](\.\./\.\./\.\./\.\./index\.md\#source)__ *filename*](#74)  
[classmethod __select__ *object*](#75)  
[method __config\.sh__](#76)  
[method __BuildDir__ *PWD*](#77)  
[method __MakeDir__ *srcdir*](#78)  
[method __read\_configuration__](#79)  
[method __build\-cflags__ *PROJECT* *DEFS* *namevar* *versionvar* *defsvar*](#80)  
[method __critcl__ ?*args*?](#81)  
[method __Autoconf__](#82)  
[method __BuildDir__ *PWD*](#83)  
[method __ConfigureOpts__](#84)  
[method __MakeDir__ *srcdir*](#85)  
[method __make \{\} autodetect__](#86)  
[method __make \{\} clean__](#87)  
[method __make \{\} compile__](#88)  
[method __make \{\} install__ *DEST*](#89)  
[method __build\-compile\-sources__ *PROJECT* *COMPILE* *CPPCOMPILE* *INCLUDES*](#90)  
[method __build\-Makefile__ *path* *PROJECT*](#91)  
[method __build\-library__ *outfile* *PROJECT*](#92)  
[method __build\-tclsh__ *outfile* *PROJECT* ?*path* __auto__?](#93)  
[method __BuildDir__ *PWD*](#94)  
[method __make \{\} autodetect__](#95)  
[method __make \{\} clean__](#96)  
[method __make \{\} compile__](#97)  
[method __make \{\} install__ *DEST*](#98)  
[method __MakeDir__ *srcdir*](#99)  
[method __NmakeOpts__](#100)  
[method __constructor__ *module\_object* *name* *info* ?*action\_body* ____?](#101)  
[method __[do](\.\./\.\./\.\./\.\./index\.md\#do)__](#102)  
[method __check__](#103)  
[method __output__](#104)  
[method __reset__](#105)  
[method __triggers__](#106)  
[method __constructor__ *parent* ?*args*?](#107)  
[method __child__ *method*](#108)  
[method __go__](#109)  
[method __cstructure__ *name* *definition* ?*argdat* ____?](#110)  
[method __include__ *header*](#111)  
[method __include\_dir__ ?*args*?](#112)  
[method __include\_directory__ ?*args*?](#113)  
[method __c\_header__ *body*](#114)  
[method __c\_code__ *body*](#115)  
[method __c\_function__ *header* *body* ?*info* ____?](#116)  
[method __c\_tcloomethod__ *name* *body* ?*arginfo* ____?](#117)  
[method __cmethod__ *name* *body* ?*arginfo* ____?](#118)  
[method __c\_tclproc\_nspace__ *nspace*](#119)  
[method __c\_tclcmd__ *name* *body* ?*arginfo* ____?](#120)  
[method __c\_tclproc\_raw__ *name* *body* ?*arginfo* ____?](#121)  
[method __tcltype__ *name* *argdat*](#122)  
[method __project\-compile\-products__](#123)  
[method __implement__ *path*](#124)  
[method __initialize__](#125)  
[method __linktype__](#126)  
[method __generate\-cfile\-constant__](#127)  
[method __generate\-cfile\-header__](#128)  
[method __generate\-cfile\-tclapi__](#129)  
[method __generate\-loader\-module__](#130)  
[method __Collate\_Source__ *CWD*](#131)  
[method __select__](#132)  
[classmethod __select__ *object*](#133)  
[method __code__ *section* *body*](#134)  
[method __Collate\_Source__ *CWD*](#135)  
[method __project\-compile\-products__](#136)  
[method __generate\-debug__ ?*spaces* ____?](#137)  
[method __generate\-cfile\-constant__](#138)  
[method __generate\-cfile\-public\-structure__](#139)  
[method __generate\-cfile\-header__](#140)  
[method __generate\-cfile\-global__](#141)  
[method __generate\-cfile\-private\-typedef__](#142)  
[method __generate\-cfile\-private\-structure__](#143)  
[method __generate\-cfile\-functions__](#144)  
[method __generate\-cfile\-tclapi__](#145)  
[method __generate\-hfile\-public\-define__](#146)  
[method __generate\-hfile\-public\-macro__](#147)  
[method __generate\-hfile\-public\-typedef__](#148)  
[method __generate\-hfile\-public\-structure__](#149)  
[method __generate\-hfile\-public\-headers__](#150)  
[method __generate\-hfile\-public\-function__](#151)  
[method __generate\-hfile\-public\-includes__](#152)  
[method __generate\-hfile\-public\-verbatim__](#153)  
[method __generate\-loader\-external__](#154)  
[method __generate\-loader\-module__](#155)  
[method __generate\-stub\-function__](#156)  
[method __IncludeAdd__ *headervar* ?*args*?](#157)  
[method __generate\-tcl\-loader__](#158)  
[method __generate\-tcl\-pre__](#159)  
[method __generate\-tcl\-post__](#160)  
[method __linktype__](#161)  
[method __Ofile__ *filename*](#162)  
[method __project\-static\-packages__](#163)  
[method __toolset\-include\-directory__](#164)  
[method __target__ *method* ?*args*?](#165)  
[method __project\-compile\-products__](#166)  
[method __generate\-loader\-module__](#167)  
[method __project\-compile\-products__](#168)  
[method __linker\-products__ *configdict*](#169)  
[method __initialize__](#170)  
[variable __make\_object__](#171)  
[method __\_MorphPatterns__](#172)  
[method __add__ ?*args*?](#173)  
[method __install\-headers__ ?*args*?](#174)  
[method __make \{\} \_preamble__](#175)  
[method __make \{\} pkginfo__](#176)  
[method __make \{\} objects__](#177)  
[method __make \{\} object__ *name*](#178)  
[method __make \{\} reset__](#179)  
[method __make \{\} trigger__ ?*args*?](#180)  
[method __make \{\} depends__ ?*args*?](#181)  
[method __make \{\} filename__ *name*](#182)  
[method __make \{\} target__ *name* *Info* *body*](#183)  
[method __make \{\} todo__](#184)  
[method __make \{\} do__](#185)  
[method __child__ *which*](#186)  
[method __generate\-c__](#187)  
[method __generate\-h__](#188)  
[method __generate\-loader__](#189)  
[method __initialize__](#190)  
[method __implement__ *path*](#191)  
[method __linktype__](#192)  
[method __\_MorphPatterns__](#193)  
[method __constructor__ ?*args*?](#194)  
[method __add\_object__ *object*](#195)  
[method __add\_project__ *pkg* *info* ?*oodefine* ____?](#196)  
[method __add\_tool__ *pkg* *info* ?*oodefine* ____?](#197)  
[method __build\-tclcore__](#198)  
[method __child__ *which*](#199)  
[method __linktype__](#200)  
[method __project__ *pkg* ?*args*?](#201)  
[method __tclcore__](#202)  
[method __tkcore__](#203)  
[method __[tool](\.\./tool/tool\.md)__ *pkg* ?*args*?](#204)  
[method __clean__ *PATH*](#205)  
[method __project\-compile\-products__](#206)  
[method __go__](#207)  
[method __generate\-decls__ *pkgname* *path*](#208)  
[method __implement__ *path*](#209)  
[method __generate\-make__ *path*](#210)  
[method __linktype__](#211)  
[method __package\-ifneeded__ ?*args*?](#212)  
[method __shared\_library__ ?*filename* ____?](#213)  
[method __static\_library__ ?*filename* ____?](#214)  
[method __build\-tclkit\_main__ *PROJECT* *PKG\_OBJS*](#215)  
[method __Collate\_Source__ *CWD*](#216)  
[method __wrap__ *PWD* *exename* *vfspath* ?*args*?](#217)  
[classmethod __Sandbox__ *object*](#218)  
[classmethod __select__ *object*](#219)  
[classmethod __claim\_option__](#220)  
[classmethod __claim\_object__ *object*](#221)  
[classmethod __claim\_path__ *path*](#222)  
[method __scm\_info__](#223)  
[method __DistroMixIn__](#224)  
[method __Sandbox__](#225)  
[method __SrcDir__](#226)  
[method __ScmTag__](#227)  
[method __ScmClone__](#228)  
[method __ScmUnpack__](#229)  
[method __ScmUpdate__](#230)  
[method __Unpack__](#231)  
[classmethod __claim\_object__ *object*](#232)  
[classmethod __claim\_option__](#233)  
[classmethod __claim\_path__ *path*](#234)  
[method __ScmUnpack__](#235)  
[classmethod __claim\_object__ *obj*](#236)  
[classmethod __claim\_option__](#237)  
[classmethod __claim\_path__ *path*](#238)  
[method __scm\_info__](#239)  
[method __ScmClone__](#240)  
[method __ScmTag__](#241)  
[method __ScmUnpack__](#242)  
[method __ScmUpdate__](#243)  
[classmethod __claim\_object__ *obj*](#244)  
[classmethod __claim\_option__](#245)  
[classmethod __claim\_path__ *path*](#246)  
[method __ScmTag__](#247)  
[method __ScmUnpack__](#248)  
[method __ScmUpdate__](#249)  
[method __\_MorphPatterns__](#250)  
[method __BuildDir__ *PWD*](#251)  
[method __child__ *which*](#252)  
[method __compile__](#253)  
[method __go__](#254)  
[method __install__ ?*args*?](#255)  
[method __linktype__](#256)  
[method __linker\-products__ *configdict*](#257)  
[method __linker\-external__ *configdict*](#258)  
[method __linker\-extra__ *configdict*](#259)  
[method __env\-bootstrap__](#260)  
[method __env\-exec__](#261)  
[method __env\-install__](#262)  
[method __env\-load__](#263)  
[method __env\-present__](#264)  
[method __sources__](#265)  
[method __[update](\.\./\.\./\.\./\.\./index\.md\#update)__](#266)  
[method __unpack__](#267)  
[method __env\-bootstrap__](#268)  
[method __env\-present__](#269)  
[method __linktype__](#270)  
[method __env\-bootstrap__](#271)  
[method __env\-install__](#272)  
[method __env\-present__](#273)  
[method __install__ *DEST*](#274)  
[method __kettle__ *path* ?*args*?](#275)  
[method __install__ *DEST*](#276)  
[method __install__ *DEST*](#277)  
[method __env\-bootstrap__](#278)  
[method __env\-install__](#279)  
[method __env\-present__](#280)  
[method __install__ *DEST*](#281)  
[method __install\-module__ *DEST* ?*args*?](#282)  
[method __env\-bootstrap__](#283)  
[method __env\-install__](#284)  
[method __install__ *DEST*](#285)  
[method __install\-module__ *DEST* ?*args*?](#286)  
[method __clean__](#287)  
[method __env\-install__](#288)  
[method __project\-compile\-products__](#289)  
[method __ComputeInstall__](#290)  
[method __go__](#291)  
[method __linker\-products__ *configdict*](#292)  
[method __project\-static\-packages__](#293)  
[method __BuildDir__ *PWD*](#294)  
[method __compile__](#295)  
[method __Configure__](#296)  
[method __install__ *DEST*](#297)  
[method __install__ *DEST*](#298)  
[method __install__ *DEST*](#299)  
[method __env\-bootstrap__](#300)  
[method __env\-present__](#301)  
[method __env\-install__](#302)  
[method __go__](#303)  
[method __linktype__](#304)  

# <a name='description'></a>DESCRIPTION

The Practcl module is a tool for integrating large modules for C API Tcl code
that requires custom Tcl types and TclOO objects\.

The concept with Practcl is that is a single file package that can assist any
tcl based project with distribution, compilation, linking, VFS preparation,
executable assembly, and installation\. Practcl also allows one project to invoke
the build system from another project, allowing complex projects such as a
statically linked basekit to be assembled with relative ease\.

Practcl ships as a single file, and aside from a Tcl 8\.6 interpreter, has no
external dependencies\.

Making a practcl project

# <a name='section2'></a>Commands

  - <a name='1'></a>proc __practcl::cat__ *fname*

    Concatenate a file

  - <a name='2'></a>proc __practcl::docstrip__ *text*

    Strip the global comments from tcl code\. Used to prevent the documentation
    markup comments from clogging up files intended for distribution in machine
    readable format\.

  - <a name='3'></a>proc __putb__ ?*map*? *text*

    Append a line of text to a variable\. Optionally apply a string mapping\.

  - <a name='4'></a>proc __[Proc](\.\./\.\./\.\./\.\./index\.md\#proc)__ *name* *arglist* *body*

    Generate a proc if no command already exists by that name

  - <a name='5'></a>proc __noop__ ?*args*?

    A command to do nothing\. A handy way of negating an instruction without
    having to comment it completely out\. It's also a handy attachment point for
    an object to be named later

  - <a name='6'></a>proc __practcl::debug__ ?*args*?

  - <a name='7'></a>proc __practcl::doexec__ ?*args*?

    Drop in a static copy of Tcl

  - <a name='8'></a>proc __practcl::doexec\_in__ *path* ?*args*?

  - <a name='9'></a>proc __practcl::dotclexec__ ?*args*?

  - <a name='10'></a>proc __practcl::domake__ *path* ?*args*?

  - <a name='11'></a>proc __practcl::domake\.tcl__ *path* ?*args*?

  - <a name='12'></a>proc __practcl::fossil__ *path* ?*args*?

  - <a name='13'></a>proc __practcl::fossil\_status__ *dir*

  - <a name='14'></a>proc __practcl::os__

  - <a name='15'></a>proc __practcl::mkzip__ *exename* *barekit* *vfspath*

    Build a zipfile\. On tcl8\.6 this invokes the native Zip implementation on
    older interpreters this invokes zip via exec

  - <a name='16'></a>proc __practcl::sort\_dict__ *list*

    Dictionary sort a key/value list\. Needed because pre tcl8\.6 does not have
    *lsort \-stride 2*

  - <a name='17'></a>proc __practcl::local\_os__

    Returns a dictionary describing the local operating system\. Fields return
    include:

      * download \- Filesystem path where fossil repositories and source tarballs
        are downloaded for the current user

      * EXEEXT \- The extension to give to executables\. \(i\.e\. \.exe on windows\)

      * fossil\_mirror \- A URI for a local network web server who acts as a
        fossil repository mirror

      * local\_install \- Filesystem path where packages for local consumption by
        the current user are installed

      * prefix \- The prefix as given to the Tcl core/TEA for installation to
        local\_install in \./configure

      * sandbox \- The file location where this project unpacks external projects

      * TEACUP\_PROFILE \- The ActiveState/Teacup canonical name for this platform
        \(i\.e\. win32\-ix86 macosx10\.5\-i386\-x86\_84\)

      * TEACUP\_OS \- The local operating system \(windows, macosx, openbsd, etc\)\.
        Gives the same answer as tcl\.m4, except that macosx is given as macosx
        instead of Darwin\.

      * TEA\_PLATFORM \- The platform returned by uname \-s\-uname \-r \(on Unix\), or
        "windows" on Windows

      * TEACUP\_ARCH \- The processor architecture for the local os \(i\.e\. ix86,
        x86\_64\)

      * TEACUP\_ARCH \- The processor architecture for the local os \(i\.e\. ix86,
        x86\_64\)

      * teapot \- Filesystem path where teapot package files are downloaded for
        the current user

      * userhome \- File path to store localized preferences, cache download
        files, etc for the current user

    This command uses a combination of local checks with Exec, any tclConfig\.sh
    file that is resident, autoconf data where already computed, and data
    gleaned from a file named practcl\.rc in userhome\. The location for userhome
    varies by platform and operating system:

      * Windows: ::env\(LOCALAPPDATA\)/Tcl

      * Macos: ~/Library/Application Support/Tcl

      * Other: ~/tcl

  - <a name='18'></a>proc __practcl::config\.tcl__ *path*

    A transparent call to ::practcl::read\_configuration to preserve backward
    compadibility with older copies of Practcl

  - <a name='19'></a>proc __practcl::read\_configuration__ *path*

    Detect local platform\. This command looks for data gleaned by autoconf or
    autosetup in the path specified, or perform its own logic tests if neither
    has been run\. A file named config\.site present in the location indicates
    that this project is cross compiling, and the data stored in that file is
    used for the compiler and linker\.

    This command looks for information from the following files, in the
    following order:

      * config\.tcl \- A file generated by autoconf/configure in newer editions of
        TEA, encoded as a Tcl script\.

      * config\.site \- A file containing cross compiler information, encoded as a
        SH script

      * ::env\(VisualStudioVersion\) \- On Windows, and environmental value that
        indicates MS Visual Studio is installed

    This command returns a dictionary containing all of the data cleaned from
    the sources above\. In the absence of any guidance this command returns the
    same output as ::practcl::local\_os\. In this mode, if the environmental
    variable VisualStudioVersion exists, this command will provide a template of
    fields that are appropriate for compiling on Windows under Microsoft Visual
    Studio\. The USEMSVC flag in the dictionary is a boolean flag to indicate if
    this is indeed the case\.

  - <a name='20'></a>proc __practcl::tcllib\_require__ *pkg* ?*args*?

    Try to load a package, and failing that retrieve tcllib

  - <a name='21'></a>proc __practcl::platform::tcl\_core\_options__ *os*

    Return the string to pass to \./configure to compile the Tcl core for the
    given OS\.

      * windows: \-\-with\-tzdata \-\-with\-encoding utf\-8

      * macosx: \-\-enable\-corefoundation=yes \-\-enable\-framework=no \-\-with\-tzdata
        \-\-with\-encoding utf\-8

      * other: \-\-with\-tzdata \-\-with\-encoding utf\-8

  - <a name='22'></a>proc __practcl::platform::tk\_core\_options__ *os*

  - <a name='23'></a>proc __practcl::read\_rc\_file__ *filename* ?*localdat* ____?

    Read a stylized key/value list stored in a file

  - <a name='24'></a>proc __practcl::read\_sh\_subst__ *line* *info*

    Converts a XXX\.sh file into a series of Tcl variables

  - <a name='25'></a>proc __practcl::read\_sh\_file__ *filename* ?*localdat* ____?

  - <a name='26'></a>proc __practcl::read\_Config\.sh__ *filename*

    A simpler form of read\_sh\_file tailored to pulling data from
    \(tcl&#124;tk\)Config\.sh

  - <a name='27'></a>proc __practcl::read\_Makefile__ *filename*

    A simpler form of read\_sh\_file tailored to pulling data from a Makefile

  - <a name='28'></a>proc __practcl::cputs__ *varname* ?*args*?

    Append arguments to a buffer The command works like puts in that each call
    will also insert a line feed\. Unlike puts, blank links in the interstitial
    are suppressed

  - <a name='29'></a>proc __practcl::tcl\_to\_c__ *body*

  - <a name='30'></a>proc __practcl::\_tagblock__ *text* ?*style* __tcl__? ?*note* ____?

  - <a name='31'></a>proc __practcl::de\_shell__ *data*

  - <a name='32'></a>proc __practcl::grep__ *pattern* ?*files* ____?

    Search for the pattern *pattern* amongst $files

  - <a name='33'></a>proc __practcl::file\_lexnormalize__ *sp*

  - <a name='34'></a>proc __practcl::file\_relative__ *base* *dst*

    Calculate a relative path between base and dst

    Example:

        ::practcl::file_relative ~/build/tcl/unix ~/build/tcl/library
        > ../library

  - <a name='35'></a>proc __practcl::findByPattern__ *basedir* *patterns*

  - <a name='36'></a>proc __practcl::log__ *fname* *comment*

    Record an event in the practcl log

  - <a name='37'></a>proc __practcl::\_pkgindex\_simpleIndex__ *path*

  - <a name='38'></a>proc __practcl::\_pkgindex\_directory__ *path*

    Return true if the pkgindex file contains any statement other than "package
    ifneeded" and/or if any package ifneeded loads a DLL

  - <a name='39'></a>proc __practcl::\_pkgindex\_path\_subdir__ *path*

    Helper function for ::practcl::pkgindex\_path

  - <a name='40'></a>proc __practcl::pkgindex\_path__ ?*args*?

    Index all paths given as though they will end up in the same virtual file
    system

  - <a name='41'></a>proc __practcl::installDir__ *d1* *d2*

    Delete the contents of *d2*, and then recusively Ccopy the contents of
    *d1* to *d2*\.

  - <a name='42'></a>proc __practcl::copyDir__ *d1* *d2* ?*toplevel* __1__?

    Recursively copy the contents of *d1* to *d2*

  - <a name='43'></a>proc __practcl::buildModule__ *modpath*

  - <a name='44'></a>proc __practcl::installModule__ *modpath* *DEST*

    Install a module from MODPATH to the directory specified\. *dpath* is
    assumed to be the fully qualified path where module is to be placed\. Any
    existing files will be deleted at that path\. If the path is symlink the
    process will return with no error and no action\. If the module has contents
    in the build/ directory that are newer than the \.tcl files in the module
    source directory, and a build/build\.tcl file exists, the build/build\.tcl
    file is run\. If the source directory includes a file named index\.tcl, the
    directory is assumed to be in the tao style of modules, and the entire
    directory \(and all subdirectories\) are copied verbatim\. If no index\.tcl file
    is present, all \.tcl files are copied from the module source directory, and
    a pkgIndex\.tcl file is generated if non yet exists\. I a folder named htdocs
    exists in the source directory, that directory is copied verbatim to the
    destination\.

  - <a name='45'></a>proc __practcl::trigger__ ?*args*?

    Trigger build targets, and recompute dependencies

    Internals:

        ::practcl::LOCAL make trigger {*}$args
        foreach {name obj} [::practcl::LOCAL make objects] {
          set ::make($name) [$obj do]
        }

  - <a name='46'></a>proc __practcl::depends__ ?*args*?

    Calculate if a dependency for any of the arguments needs to be fulfilled or
    rebuilt\.

    Internals:

        ::practcl::LOCAL make depends {*}$args

  - <a name='47'></a>proc __practcl::target__ *name* *info* ?*action* ____?

    Declare a build product\. This proc is just a shorthand for
    *::practcl::LOCAL make task $name $info $action*

    Registering a build product with this command will create an entry in the
    global array, and populate a value in the global array\.

    Internals:

        set obj [::practcl::LOCAL make task $name $info $action]
        set ::make($name) 0
        set filename [$obj define get filename]
        if {$filename ne {}} {
          set ::target($name) $filename
        }

# <a name='section3'></a>Classes

## <a name='subsection1'></a>Class  practcl::doctool

    { set authors {
       {John Doe} {jdoe@illustrious.edu}
       {Tom RichardHarry} {tomdickharry@illustrius.edu}
     }
     # Create the object
     ::practcl::doctool create AutoDoc
     set fout [open [file join $moddir module.tcl] w]
     foreach file [glob [file join $srcdir *.tcl]] {
       set content [::practcl::cat [file join $srcdir $file]]
        # Scan the file
        AutoDoc scan_text $content
        # Strip the comments from the distribution
        puts $fout [::practcl::docstrip $content]
     }
     # Write out the manual page
     set manout [open [file join $moddir module.man] w]
     dict set args header [string map $modmap [::practcl::cat [file join $srcdir manual.txt]]]
     dict set args footer [string map $modmap [::practcl::cat [file join $srcdir footer.txt]]]
     dict set args authors $authors
     puts $manout [AutoDoc manpage {*}$args]
     close $manout


    }

Tool for build scripts to dynamically generate manual files from comments in
source code files

__Methods__

  - <a name='48'></a>method __constructor__

  - <a name='49'></a>method __argspec__ *argspec*

    Process an argument list into an informational dict\. This method also
    understands non\-positional arguments expressed in the notation of Tip 471
    [https://core\.tcl\-lang\.org/tips/doc/trunk/tip/479\.md](https://core\.tcl\-lang\.org/tips/doc/trunk/tip/479\.md)\.

    The output will be a dictionary of all of the fields and whether the fields
    are __positional__, __mandatory__, and whether they have a
    __default__ value\.

    Example:

    my argspec {a b {c 10}}

    > a {positional 1 mandatory 1} b {positional 1 mandatory 1} c {positional 1 mandatory 0 default 10}

  - <a name='50'></a>method __[comment](\.\./\.\./\.\./\.\./index\.md\#comment)__ *block*

    Convert a block of comments into an informational dictionary\. If lines in
    the comment start with a single word ending in a colon, all subsequent lines
    are appended to a dictionary field of that name\. If no fields are given, all
    of the text is appended to the __description__ field\.

    Example:

    my comment {Does something cool}
    > description {Does something cool}

    my comment {
    title : Something really cool
    author : Sean Woods
    author : John Doe
    description :
    This does something really cool!
    }
    > description {This does something really cool!}
      title {Something really cool}
      author {Sean Woods
      John Doe}

  - <a name='51'></a>method __keyword\.Annotation__ *resultvar* *commentblock* *type* *name* *body*

  - <a name='52'></a>method __keyword\.Class__ *resultvar* *commentblock* *name* *body*

    Process an oo::objdefine call that modifies the class object itself

  - <a name='53'></a>method __keyword\.class__ *resultvar* *commentblock* *name* *body*

    Process an oo::define, clay::define, etc statement\.

  - <a name='54'></a>method __keyword\.Class\_Method__ *resultvar* *commentblock* *name* ?*args*?

    Process a statement for a clay style class method

  - <a name='55'></a>method __keyword\.method__ *resultvar* *commentblock* *name* ?*args*?

    Process a statement for a tcloo style object method

  - <a name='56'></a>method __keyword\.proc__ *commentblock* *name* *argspec*

    Process a proc statement

  - <a name='57'></a>method __reset__

    Reset the state of the object and its embedded coroutine

  - <a name='58'></a>method __Main__

    Main body of the embedded coroutine for the object

  - <a name='59'></a>method __section\.method__ *keyword* *method* *minfo*

    Generate the manual page text for a method or proc

  - <a name='60'></a>method __section\.annotation__ *type* *name* *iinfo*

  - <a name='61'></a>method __section\.class__ *class\_name* *class\_info*

    Generate the manual page text for a class

  - <a name='62'></a>method __section\.command__ *procinfo*

    Generate the manual page text for the commands section

  - <a name='63'></a>method __[manpage](\.\./\.\./\.\./\.\./index\.md\#manpage)__ ?__header *value*__? ?__footer *value*__? ?__authors *list*__?

    Generate the manual page\. Returns the completed text suitable for saving in
    \.man file\. The header argument is a block of doctools text to go in before
    the machine generated section\. footer is a block of doctools text to go in
    after the machine generated section\. authors is a list of individual authors
    and emails in the form of AUTHOR EMAIL ?AUTHOR EMAIL?\.\.\.

  - <a name='64'></a>method __scan\_text__ *text*

    Scan a block of text

  - <a name='65'></a>method __scan\_file__ *filename*

    Scan a file of text

## <a name='subsection2'></a>Class  practcl::metaclass

The metaclass for all practcl objects

__Methods__

  - <a name='66'></a>method __\_MorphPatterns__

  - <a name='67'></a>method __[define](\.\./\.\./\.\./\.\./index\.md\#define)__ *submethod* ?*args*?

  - <a name='68'></a>method __graft__ ?*args*?

  - <a name='69'></a>method __initialize__

  - <a name='70'></a>method __link__ *command* ?*args*?

  - <a name='71'></a>method __morph__ *classname*

  - <a name='72'></a>method __script__ *script*

  - <a name='73'></a>method __select__

  - <a name='74'></a>method __[source](\.\./\.\./\.\./\.\./index\.md\#source)__ *filename*

## <a name='subsection3'></a>Class  practcl::toolset

Ancestor\-less class intended to be a mixin which defines a family of build
related behaviors that are modified when targetting either gcc or msvc

__Class Methods__

  - <a name='75'></a>classmethod __select__ *object*

    Perform the selection for the toolset mixin

__Methods__

  - <a name='76'></a>method __config\.sh__

    find or fake a key/value list describing this project

  - <a name='77'></a>method __BuildDir__ *PWD*

    Compute the location where the product will be built

  - <a name='78'></a>method __MakeDir__ *srcdir*

    Return where the Makefile is located relative to *srcdir*\. For this
    implementation the MakeDir is always srcdir\.

  - <a name='79'></a>method __read\_configuration__

    Read information about the build process for this package\. For this
    implementation, data is sought in the following locations in the following
    order: config\.tcl \(generated by practcl\.\) PKGConfig\.sh\. The Makefile

    If the Makefile needs to be consulted, but does not exist, the Configure
    method is invoked

  - <a name='80'></a>method __build\-cflags__ *PROJECT* *DEFS* *namevar* *versionvar* *defsvar*

    method DEFS This method populates 4 variables: name \- The name of the
    package version \- The version of the package defs \- C flags passed to the
    compiler includedir \- A list of paths to feed to the compiler for finding
    headers

  - <a name='81'></a>method __critcl__ ?*args*?

    Invoke critcl in an external process

## <a name='subsection4'></a>Class  practcl::toolset\.gcc

*ancestors*: __practcl::toolset__

__Methods__

  - <a name='82'></a>method __Autoconf__

  - <a name='83'></a>method __BuildDir__ *PWD*

  - <a name='84'></a>method __ConfigureOpts__

  - <a name='85'></a>method __MakeDir__ *srcdir*

    Detect what directory contains the Makefile template

  - <a name='86'></a>method __make \{\} autodetect__

  - <a name='87'></a>method __make \{\} clean__

  - <a name='88'></a>method __make \{\} compile__

  - <a name='89'></a>method __make \{\} install__ *DEST*

  - <a name='90'></a>method __build\-compile\-sources__ *PROJECT* *COMPILE* *CPPCOMPILE* *INCLUDES*

  - <a name='91'></a>method __build\-Makefile__ *path* *PROJECT*

  - <a name='92'></a>method __build\-library__ *outfile* *PROJECT*

    Produce a static or dynamic library

  - <a name='93'></a>method __build\-tclsh__ *outfile* *PROJECT* ?*path* __auto__?

    Produce a static executable

## <a name='subsection5'></a>Class  practcl::toolset\.msvc

*ancestors*: __practcl::toolset__

__Methods__

  - <a name='94'></a>method __BuildDir__ *PWD*

    MSVC always builds in the source directory

  - <a name='95'></a>method __make \{\} autodetect__

    Do nothing

  - <a name='96'></a>method __make \{\} clean__

  - <a name='97'></a>method __make \{\} compile__

  - <a name='98'></a>method __make \{\} install__ *DEST*

  - <a name='99'></a>method __MakeDir__ *srcdir*

    Detect what directory contains the Makefile template

  - <a name='100'></a>method __NmakeOpts__

## <a name='subsection6'></a>Class  practcl::make\_obj

*ancestors*: __practcl::metaclass__

A build deliverable object\. Normally an object file, header, or tcl script which
must be compiled or generated in some way

__Methods__

  - <a name='101'></a>method __constructor__ *module\_object* *name* *info* ?*action\_body* ____?

  - <a name='102'></a>method __[do](\.\./\.\./\.\./\.\./index\.md\#do)__

  - <a name='103'></a>method __check__

  - <a name='104'></a>method __output__

  - <a name='105'></a>method __reset__

  - <a name='106'></a>method __triggers__

## <a name='subsection7'></a>Class  practcl::object

*ancestors*: __practcl::metaclass__

A generic Practcl object

__Methods__

  - <a name='107'></a>method __constructor__ *parent* ?*args*?

  - <a name='108'></a>method __child__ *method*

  - <a name='109'></a>method __go__

## <a name='subsection8'></a>Class  practcl::dynamic

Dynamic blocks do not generate their own \.c files, instead the contribute to the
amalgamation of the main library file

__Methods__

  - <a name='110'></a>method __cstructure__ *name* *definition* ?*argdat* ____?

    Parser functions

  - <a name='111'></a>method __include__ *header*

  - <a name='112'></a>method __include\_dir__ ?*args*?

  - <a name='113'></a>method __include\_directory__ ?*args*?

  - <a name='114'></a>method __c\_header__ *body*

  - <a name='115'></a>method __c\_code__ *body*

  - <a name='116'></a>method __c\_function__ *header* *body* ?*info* ____?

  - <a name='117'></a>method __c\_tcloomethod__ *name* *body* ?*arginfo* ____?

  - <a name='118'></a>method __cmethod__ *name* *body* ?*arginfo* ____?

    Alias to classic name

  - <a name='119'></a>method __c\_tclproc\_nspace__ *nspace*

  - <a name='120'></a>method __c\_tclcmd__ *name* *body* ?*arginfo* ____?

  - <a name='121'></a>method __c\_tclproc\_raw__ *name* *body* ?*arginfo* ____?

    Alias to classic name

  - <a name='122'></a>method __tcltype__ *name* *argdat*

  - <a name='123'></a>method __project\-compile\-products__

    Module interactions

  - <a name='124'></a>method __implement__ *path*

  - <a name='125'></a>method __initialize__

    Practcl internals

  - <a name='126'></a>method __linktype__

  - <a name='127'></a>method __generate\-cfile\-constant__

  - <a name='128'></a>method __generate\-cfile\-header__

  - <a name='129'></a>method __generate\-cfile\-tclapi__

    Generate code that provides implements Tcl API calls

  - <a name='130'></a>method __generate\-loader\-module__

    Generate code that runs when the package/module is initialized into the
    interpreter

  - <a name='131'></a>method __Collate\_Source__ *CWD*

  - <a name='132'></a>method __select__

    Once an object marks itself as some flavor of dynamic, stop trying to morph
    it into something else

## <a name='subsection9'></a>Class  practcl::product

A deliverable for the build system

__Class Methods__

  - <a name='133'></a>classmethod __select__ *object*

__Methods__

  - <a name='134'></a>method __code__ *section* *body*

  - <a name='135'></a>method __Collate\_Source__ *CWD*

  - <a name='136'></a>method __project\-compile\-products__

  - <a name='137'></a>method __generate\-debug__ ?*spaces* ____?

  - <a name='138'></a>method __generate\-cfile\-constant__

  - <a name='139'></a>method __generate\-cfile\-public\-structure__

    Populate const static data structures

  - <a name='140'></a>method __generate\-cfile\-header__

  - <a name='141'></a>method __generate\-cfile\-global__

  - <a name='142'></a>method __generate\-cfile\-private\-typedef__

  - <a name='143'></a>method __generate\-cfile\-private\-structure__

  - <a name='144'></a>method __generate\-cfile\-functions__

    Generate code that provides subroutines called by Tcl API methods

  - <a name='145'></a>method __generate\-cfile\-tclapi__

    Generate code that provides implements Tcl API calls

  - <a name='146'></a>method __generate\-hfile\-public\-define__

  - <a name='147'></a>method __generate\-hfile\-public\-macro__

  - <a name='148'></a>method __generate\-hfile\-public\-typedef__

  - <a name='149'></a>method __generate\-hfile\-public\-structure__

  - <a name='150'></a>method __generate\-hfile\-public\-headers__

  - <a name='151'></a>method __generate\-hfile\-public\-function__

  - <a name='152'></a>method __generate\-hfile\-public\-includes__

  - <a name='153'></a>method __generate\-hfile\-public\-verbatim__

  - <a name='154'></a>method __generate\-loader\-external__

  - <a name='155'></a>method __generate\-loader\-module__

  - <a name='156'></a>method __generate\-stub\-function__

  - <a name='157'></a>method __IncludeAdd__ *headervar* ?*args*?

  - <a name='158'></a>method __generate\-tcl\-loader__

  - <a name='159'></a>method __generate\-tcl\-pre__

    This methods generates any Tcl script file which is required to
    pre\-initialize the C library

  - <a name='160'></a>method __generate\-tcl\-post__

  - <a name='161'></a>method __linktype__

  - <a name='162'></a>method __Ofile__ *filename*

  - <a name='163'></a>method __project\-static\-packages__

    Methods called by the master project

  - <a name='164'></a>method __toolset\-include\-directory__

    Methods called by the toolset

  - <a name='165'></a>method __target__ *method* ?*args*?

## <a name='subsection10'></a>Class  practcl::product\.cheader

*ancestors*: __practcl::product__

A product which generated from a C header file\. Which is to say, nothing\.

__Methods__

  - <a name='166'></a>method __project\-compile\-products__

  - <a name='167'></a>method __generate\-loader\-module__

## <a name='subsection11'></a>Class  practcl::product\.csource

*ancestors*: __practcl::product__

A product which generated from a C source file\. Normally an object \(\.o\) file\.

__Methods__

  - <a name='168'></a>method __project\-compile\-products__

## <a name='subsection12'></a>Class  practcl::product\.clibrary

*ancestors*: __practcl::product__

A product which is generated from a compiled C library\. Usually a \.a or a \.dylib
file, but in complex cases may actually just be a conduit for one project to
integrate the source code of another

__Methods__

  - <a name='169'></a>method __linker\-products__ *configdict*

## <a name='subsection13'></a>Class  practcl::product\.dynamic

*ancestors*: __practcl::dynamic__ __practcl::product__

A product which is generated from C code that itself is generated by practcl or
some other means\. This C file may or may not produce its own \.o file, depending
on whether it is eligible to become part of an amalgamation

__Methods__

  - <a name='170'></a>method __initialize__

## <a name='subsection14'></a>Class  practcl::product\.critcl

*ancestors*: __practcl::dynamic__ __practcl::product__

A binary product produced by critcl\. Note: The implementation is not written
yet, this class does nothing\.

## <a name='subsection15'></a>Class  practcl::module

*ancestors*: __practcl::object__ __practcl::product\.dynamic__

In the end, all C code must be loaded into a module This will either be a
dynamically loaded library implementing a tcl extension, or a compiled in
segment of a custom shell/app

__Variable__

  - <a name='171'></a>variable __make\_object__

__Methods__

  - <a name='172'></a>method __\_MorphPatterns__

  - <a name='173'></a>method __add__ ?*args*?

  - <a name='174'></a>method __install\-headers__ ?*args*?

  - <a name='175'></a>method __make \{\} \_preamble__

  - <a name='176'></a>method __make \{\} pkginfo__

  - <a name='177'></a>method __make \{\} objects__

    Return a dictionary of all handles and associated objects

  - <a name='178'></a>method __make \{\} object__ *name*

    Return the object associated with handle *name*

  - <a name='179'></a>method __make \{\} reset__

    Reset all deputy objects

  - <a name='180'></a>method __make \{\} trigger__ ?*args*?

    Exercise the triggers method for all handles listed

  - <a name='181'></a>method __make \{\} depends__ ?*args*?

    Exercise the check method for all handles listed

  - <a name='182'></a>method __make \{\} filename__ *name*

    Return the file name of the build product for the listed handle

  - <a name='183'></a>method __make \{\} target__ *name* *Info* *body*

  - <a name='184'></a>method __make \{\} todo__

    Return a list of handles for object which return true for the do method

  - <a name='185'></a>method __make \{\} do__

    For each target exercise the action specified in the *action* definition
    if the *do* method returns true

  - <a name='186'></a>method __child__ *which*

  - <a name='187'></a>method __generate\-c__

    This methods generates the contents of an amalgamated \.c file which
    implements the loader for a batch of tools

  - <a name='188'></a>method __generate\-h__

    This methods generates the contents of an amalgamated \.h file which
    describes the public API of this module

  - <a name='189'></a>method __generate\-loader__

  - <a name='190'></a>method __initialize__

  - <a name='191'></a>method __implement__ *path*

  - <a name='192'></a>method __linktype__

## <a name='subsection16'></a>Class  practcl::project

*ancestors*: __practcl::module__

A toplevel project that is a collection of other projects

__Methods__

  - <a name='193'></a>method __\_MorphPatterns__

  - <a name='194'></a>method __constructor__ ?*args*?

  - <a name='195'></a>method __add\_object__ *object*

  - <a name='196'></a>method __add\_project__ *pkg* *info* ?*oodefine* ____?

  - <a name='197'></a>method __add\_tool__ *pkg* *info* ?*oodefine* ____?

  - <a name='198'></a>method __build\-tclcore__

    Compile the Tcl core\. If the define *tk* is true, compile the Tk core as
    well

  - <a name='199'></a>method __child__ *which*

  - <a name='200'></a>method __linktype__

  - <a name='201'></a>method __project__ *pkg* ?*args*?

    Exercise the methods of a sub\-object

  - <a name='202'></a>method __tclcore__

  - <a name='203'></a>method __tkcore__

  - <a name='204'></a>method __[tool](\.\./tool/tool\.md)__ *pkg* ?*args*?

## <a name='subsection17'></a>Class  practcl::library

*ancestors*: __practcl::project__

A toplevel project that produces a library

__Methods__

  - <a name='205'></a>method __clean__ *PATH*

  - <a name='206'></a>method __project\-compile\-products__

  - <a name='207'></a>method __go__

  - <a name='208'></a>method __generate\-decls__ *pkgname* *path*

  - <a name='209'></a>method __implement__ *path*

  - <a name='210'></a>method __generate\-make__ *path*

    Backward compadible call

  - <a name='211'></a>method __linktype__

  - <a name='212'></a>method __package\-ifneeded__ ?*args*?

    Create a "package ifneeded" Args are a list of aliases for which this
    package will answer to

  - <a name='213'></a>method __shared\_library__ ?*filename* ____?

  - <a name='214'></a>method __static\_library__ ?*filename* ____?

## <a name='subsection18'></a>Class  practcl::tclkit

*ancestors*: __practcl::library__

A toplevel project that produces a self\-contained executable

__Methods__

  - <a name='215'></a>method __build\-tclkit\_main__ *PROJECT* *PKG\_OBJS*

  - <a name='216'></a>method __Collate\_Source__ *CWD*

  - <a name='217'></a>method __wrap__ *PWD* *exename* *vfspath* ?*args*?

    Wrap an executable

## <a name='subsection19'></a>Class  practcl::distribution

Standalone class to manage code distribution This class is intended to be mixed
into another class \(Thus the lack of ancestors\)

__Class Methods__

  - <a name='218'></a>classmethod __Sandbox__ *object*

  - <a name='219'></a>classmethod __select__ *object*

  - <a name='220'></a>classmethod __claim\_option__

  - <a name='221'></a>classmethod __claim\_object__ *object*

  - <a name='222'></a>classmethod __claim\_path__ *path*

__Methods__

  - <a name='223'></a>method __scm\_info__

  - <a name='224'></a>method __DistroMixIn__

  - <a name='225'></a>method __Sandbox__

  - <a name='226'></a>method __SrcDir__

  - <a name='227'></a>method __ScmTag__

  - <a name='228'></a>method __ScmClone__

  - <a name='229'></a>method __ScmUnpack__

  - <a name='230'></a>method __ScmUpdate__

  - <a name='231'></a>method __Unpack__

## <a name='subsection20'></a>Class  practcl::distribution\.snapshot

*ancestors*: __practcl::distribution__

A file distribution from zip, tarball, or other non\-scm archive format

__Class Methods__

  - <a name='232'></a>classmethod __claim\_object__ *object*

  - <a name='233'></a>classmethod __claim\_option__

  - <a name='234'></a>classmethod __claim\_path__ *path*

__Methods__

  - <a name='235'></a>method __ScmUnpack__

## <a name='subsection21'></a>Class  practcl::distribution\.fossil

*ancestors*: __practcl::distribution__

A file distribution based on fossil

__Class Methods__

  - <a name='236'></a>classmethod __claim\_object__ *obj*

    Check for markers in the metadata

  - <a name='237'></a>classmethod __claim\_option__

  - <a name='238'></a>classmethod __claim\_path__ *path*

    Check for markers in the source root

__Methods__

  - <a name='239'></a>method __scm\_info__

  - <a name='240'></a>method __ScmClone__

    Clone the source

  - <a name='241'></a>method __ScmTag__

  - <a name='242'></a>method __ScmUnpack__

  - <a name='243'></a>method __ScmUpdate__

## <a name='subsection22'></a>Class  practcl::distribution\.git

*ancestors*: __practcl::distribution__

A file distribution based on git

__Class Methods__

  - <a name='244'></a>classmethod __claim\_object__ *obj*

  - <a name='245'></a>classmethod __claim\_option__

  - <a name='246'></a>classmethod __claim\_path__ *path*

__Methods__

  - <a name='247'></a>method __ScmTag__

  - <a name='248'></a>method __ScmUnpack__

  - <a name='249'></a>method __ScmUpdate__

## <a name='subsection23'></a>Class  practcl::subproject

*ancestors*: __practcl::module__

A subordinate project

__Methods__

  - <a name='250'></a>method __\_MorphPatterns__

  - <a name='251'></a>method __BuildDir__ *PWD*

  - <a name='252'></a>method __child__ *which*

  - <a name='253'></a>method __compile__

  - <a name='254'></a>method __go__

  - <a name='255'></a>method __install__ ?*args*?

    Install project into the local build system

  - <a name='256'></a>method __linktype__

  - <a name='257'></a>method __linker\-products__ *configdict*

  - <a name='258'></a>method __linker\-external__ *configdict*

  - <a name='259'></a>method __linker\-extra__ *configdict*

  - <a name='260'></a>method __env\-bootstrap__

    Methods for packages/tools that can be downloaded possibly built and used
    internally by this Practcl process Load the facility into the interpreter

  - <a name='261'></a>method __env\-exec__

    Return a file path that exec can call

  - <a name='262'></a>method __env\-install__

    Install the tool into the local environment

  - <a name='263'></a>method __env\-load__

    Do whatever is necessary to get the tool into the local environment

  - <a name='264'></a>method __env\-present__

    Check if tool is available for load/already loaded

  - <a name='265'></a>method __sources__

  - <a name='266'></a>method __[update](\.\./\.\./\.\./\.\./index\.md\#update)__

  - <a name='267'></a>method __unpack__

## <a name='subsection24'></a>Class  practcl::subproject\.source

*ancestors*: __practcl::subproject__ __practcl::library__

A project which the kit compiles and integrates the source for itself

__Methods__

  - <a name='268'></a>method __env\-bootstrap__

  - <a name='269'></a>method __env\-present__

  - <a name='270'></a>method __linktype__

## <a name='subsection25'></a>Class  practcl::subproject\.teapot

*ancestors*: __practcl::subproject__

a copy from the teapot

__Methods__

  - <a name='271'></a>method __env\-bootstrap__

  - <a name='272'></a>method __env\-install__

  - <a name='273'></a>method __env\-present__

  - <a name='274'></a>method __install__ *DEST*

## <a name='subsection26'></a>Class  practcl::subproject\.kettle

*ancestors*: __practcl::subproject__

__Methods__

  - <a name='275'></a>method __kettle__ *path* ?*args*?

  - <a name='276'></a>method __install__ *DEST*

## <a name='subsection27'></a>Class  practcl::subproject\.critcl

*ancestors*: __practcl::subproject__

__Methods__

  - <a name='277'></a>method __install__ *DEST*

## <a name='subsection28'></a>Class  practcl::subproject\.sak

*ancestors*: __practcl::subproject__

__Methods__

  - <a name='278'></a>method __env\-bootstrap__

  - <a name='279'></a>method __env\-install__

  - <a name='280'></a>method __env\-present__

  - <a name='281'></a>method __install__ *DEST*

  - <a name='282'></a>method __install\-module__ *DEST* ?*args*?

## <a name='subsection29'></a>Class  practcl::subproject\.practcl

*ancestors*: __practcl::subproject__

__Methods__

  - <a name='283'></a>method __env\-bootstrap__

  - <a name='284'></a>method __env\-install__

  - <a name='285'></a>method __install__ *DEST*

  - <a name='286'></a>method __install\-module__ *DEST* ?*args*?

## <a name='subsection30'></a>Class  practcl::subproject\.binary

*ancestors*: __practcl::subproject__

A subordinate binary package

__Methods__

  - <a name='287'></a>method __clean__

  - <a name='288'></a>method __env\-install__

  - <a name='289'></a>method __project\-compile\-products__

  - <a name='290'></a>method __ComputeInstall__

  - <a name='291'></a>method __go__

  - <a name='292'></a>method __linker\-products__ *configdict*

  - <a name='293'></a>method __project\-static\-packages__

  - <a name='294'></a>method __BuildDir__ *PWD*

  - <a name='295'></a>method __compile__

  - <a name='296'></a>method __Configure__

  - <a name='297'></a>method __install__ *DEST*

## <a name='subsection31'></a>Class  practcl::subproject\.tea

*ancestors*: __practcl::subproject\.binary__

A subordinate TEA based binary package

## <a name='subsection32'></a>Class  practcl::subproject\.library

*ancestors*: __practcl::subproject\.binary__ __practcl::library__

A subordinate C library built by this project

__Methods__

  - <a name='298'></a>method __install__ *DEST*

## <a name='subsection33'></a>Class  practcl::subproject\.external

*ancestors*: __practcl::subproject\.binary__

A subordinate external C library

__Methods__

  - <a name='299'></a>method __install__ *DEST*

## <a name='subsection34'></a>Class  practcl::subproject\.core

*ancestors*: __practcl::subproject\.binary__

__Methods__

  - <a name='300'></a>method __env\-bootstrap__

  - <a name='301'></a>method __env\-present__

  - <a name='302'></a>method __env\-install__

  - <a name='303'></a>method __go__

  - <a name='304'></a>method __linktype__

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *practcl* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[practcl](\.\./\.\./\.\./\.\./index\.md\#practcl)

# <a name='category'></a>CATEGORY

TclOO

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2016\-2018 Sean Woods <yoda@etoyoc\.com>
