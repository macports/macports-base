# -*- tcl -*-
#
# Copyright (c) 2019 Andreas Kupries <andreas_kupries@sourceforge.net>
# Freely redistributable.
#
# _text_ccore.tcl -- Management of current context, and database of all contexts

global nextId      ; # Counter for context generation.
global contextData ; # In-memory database of known contexts.
global contextName ; # Map context handles to name.

global currentHandle  ; # Handle of context in 'currentContext'.
global currentContext ; # Current context, for direct access of all attributes

# # ## ### ##### ########
## Internals

proc ContextCommit {} {
    global contextData  currentHandle             currentContext
    set    contextData($currentHandle) [array get currentContext]
    return
}

proc NextId {} {
    global nextId
    set new $nextId
    incr     nextId
    return $new
}

# # ## ### ##### ########
## Basic management

proc ContextSetup {} {
    global contextData ; unset -nocomplain contextData ; array set contextData {}
    global contextName ; unset -nocomplain contextName ; array set contextName {}
    global nextId ; set                                            nextId 0
    
    global currentHandle  ; set                                          currentHandle  {}
    global currentContext ; unset -nocomplain currentContext ; array set currentContext {}
    return
}

proc ContextSet {id} {
    global    currentHandle currentContext contextData
    set       currentHandle $id

    #puts_stderr "--Set ($id) ([CAttrName $id])"

    # Ensure that array is clean before setting hte new block of
    # information.
    unset     currentContext
    array set currentContext $contextData($currentHandle)

    #puts_stderr "--Set $contextData($currentHandle)"
    return
}

proc ContextExists {id} {
    global contextData
    info exists contextData($id)
}

proc ContextNew {name script} {
    global currentHandle contextName currentContext
    set in [array get currentContext]
    
    set parentId  $currentHandle
    set currentHandle [NextId]

    #puts_stderr "ContextNew ${currentHandle}:($name) in ${parentId}:[CAttrName $parentId]"

    CAttrAppend NAME   /${name}:$currentHandle
    CAttrSet    parent $parentId
    CAttrSet    id     $currentHandle
    CAttrUnset  verbenv ;# Each context must have its own verbatim variant.
    
    # Customize the context - modifier commands
    uplevel $script

    # ContextCommit state for future use.
    ContextCommit
    set contextName($currentHandle) [CAttrGet NAME]
    
    return $currentHandle
}

# # ## ### ##### ########
## Generic accessors

proc CAttrName {{id {}}} {
    global contextName
    if {$id == {}} { global currentHandle ; set id $currentHandle }
    if {![info exists contextName($id)]} { return <$id> }
    return $contextName($id)
}

proc CAttrCurrent {} { global currentHandle ; return $currentHandle }

proc CAttrSet    {key value}     { global currentContext ; set    currentContext($key) $value }
proc CAttrAppend {key value}     { global currentContext ; append currentContext($key) $value }
proc CAttrIncr   {key {value 1}} { global currentContext ; incr   currentContext($key) $value }
proc CAttrGet    {key}           { global currentContext ; set currentContext($key) }
proc CAttrHas    {key}           { global currentContext ; info exists currentContext($key) }
proc CAttrUnset  {key}           { global currentContext ; catch { unset currentContext($key) } }
proc CAttrRef    {key}           { return "::currentContext($key)" }

# # ## ### ##### ########
## Verbatim
#
# Attributes:
# - verbatim    = flag if verbatim formatting requested, i.e. no paragraph reflow.
# - verbenv     = if present, id of verbatim variant of this environment

proc NewVerbatim {} {
    return [ContextNew Verbatim { VerbatimOn }]
}

proc Verbatim {} {
    if {![CAttrHas verbenv]} {
	ContextPush
	set verbenv [NewVerbatim]
	ContextPop
	# Remember the associated verbatim mode in the base
	# environment and database.
	CAttrSet verbenv $verbenv
	ContextCommit
    }
    return [CAttrGet verbenv]
}

proc VerbatimOff {} { CAttrSet verbatim 0 }
proc VerbatimOn  {} { CAttrSet verbatim 1 }
proc Verbatim?   {} { CAttrGet verbatim }

# # ## ### ##### ########

proc Parent? {} { CAttrGet parent }

# # ## ### ##### ########
return
