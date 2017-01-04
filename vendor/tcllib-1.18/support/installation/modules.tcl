# -*- tcl -*-
# --------------------------------------------------------------
# List of modules to install and definitions guiding the process of
# doing so.
#
# This file is shared between 'installer.tcl' and 'sak.tcl', like
# 'package_version.tcl'. The swiss army knife requires access to the
# data in this file to be able to check if there are modules in the
# directory hierarchy, but missing in the list of installed modules.
# --------------------------------------------------------------

proc Exclude     {m} {global excluded ; lappend excluded $m ; return }
proc Application {a} {global apps     ; lappend apps     $a ; return }

proc Module  {m pkg doc exa} {
    global modules guide

    lappend   modules $m
    set guide($m,pkg) $pkg
    set guide($m,doc) $doc
    set guide($m,exa) $exa
    return
}

set excluded [list]
set modules  [list]
set apps     [list]
array set guide {}

# --------------------------------------------------------------
# @@ Registration START

Exclude calendar
Exclude exif

#       name         pkg   doc   example
Module  aes         _tcl  _man  _null
Module  amazon-s3   _tcl  _man  _null
Module  asn         _tcl  _man  _null
Module  base32      _tcl  _man  _null
Module  base64      _tcl  _man  _null
Module  bee         _tcl  _man  _null
Module  bench       _tcl _null  _null
Module  bibtex      _tcl  _man  _exa
Module  blowfish    _tcl  _man  _null
Module  cache       _tcl  _man  _null
Module  calendar     _tci _man  _null
Module  clock       _tcl  _man _null
Module  cmdline     _tcl  _man  _null
Module  comm        _tcl  _man  _null
Module  control      _tci _man  _null
Module  coroutine   _tcl _null  _null
Module  counter     _tcl  _man  _null
Module  crc         _tcl  _man  _null
Module  cron        _tcl  _man  _null
Module  csv         _tcl  _man _exa
Module  debug       _tcl _null  _null
Module  des         _tcl  _man  _null
Module  dicttool    _tcl  _man  _null
Module  dns          _msg _man _exa
Module  docstrip    _tcl  _man  _null
Module  doctools     _doc _man _exa
Module  doctools2base _tcl _man _null
Module  doctools2idx  _tcl _man _null
Module  doctools2toc  _tcl _man _null
Module  dtplite       _tcl _man _null
Module  exif        _tcl  _man  _null
Module  fileutil    _tcl  _man  _null
Module  ftp         _tcl  _man _exa
Module  ftpd        _tcl  _man _exa
Module  fumagic     _tcl  _man  _null
Module  generator   _tcl  _man  _null
Module  gpx         _tcl _null  _null
Module  grammar_aycock _tcl _man _null
Module  grammar_fa  _tcl  _man  _null
Module  grammar_me  _tcl  _man  _null
Module  grammar_peg _tcl  _man  _null
Module  hook        _tcl  _man  _null
Module  http        _tcl  _man  _null
Module  httpd       _tcl  _man  _exa
Module  httpwget    _tcl  _null _null
Module  html        _tcl  _man  _null
Module  htmlparse   _tcl  _man  _exa
Module  ident       _tcl  _man  _null
Module  imap4       _tcl  _man  _null
Module  inifile     _tcl  _man  _null
Module  interp      _tcl  _man  _null
Module  irc         _tcl  _man _exa
Module  javascript  _tcl  _man  _null
Module  jpeg        _tcl  _man  _null
Module  json        _tcl  _man  _null
Module  lambda      _tcl  _man  _null
Module  ldap        _tcl  _man _exa
Module  log          _msg _man  {_exax logger}
Module  markdown     _tcl  _man  _null
Module  map         _tcl  _man  _null
Module  mapproj     _tcl  _man _exa
Module  math         _tci _man _exa
Module  md4         _tcl  _man  _null
Module  md5         _tcl  _man  _null
Module  md5crypt    _tcl  _man _null
Module  mime        _tcl  _man _exa
Module  multiplexer _tcl  _man  _null
Module  namespacex  _tcl  _man  _null
Module  ncgi        _tcl  _man  _null
Module  nettool     _tcl  _man  _null
Module  nmea        _tcl  _man  _null
Module  nns         _tcl  _man  _null
Module  nntp        _tcl  _man _exa
Module  ntp         _tcl  _man _exa
Module  oauth       _tcl  _man  _null
Module  oodialect   _tcl  _man   _null
Module  oometa      _tcl  _man  _null
Module  ooutil      _tcl  _man  _null
Module  otp         _tcl  _man  _null
Module  page         _trt _man  _null
Module  pki         _tcl  _man  _null
Module  pluginmgr   _tcl  _man  _null
Module  png         _tcl  _man  _null
Module  pop3        _tcl  _man  _null
Module  pop3d       _tcl  _man  _null
Module  processman  _tcl  _man  _null
Module  profiler    _tcl  _man  _null
Module  pt           _rde _man  _null
Module  rc4         _tcl  _man  _null
Module  rcs         _tcl  _man  _null
Module  report      _tcl  _man  _null
Module  rest        _tcl  _man  _null
Module  ripemd      _tcl  _man  _null
Module  sasl        _tcl  _man  _exa
Module  sha1        _tcl  _man  _null
Module  simulation  _tcl  _man  _null
Module  smtpd       _tcl  _man _exa
Module  snit        _tcl  _man  _null
Module  soundex     _tcl  _man  _null
Module  stooop      _tcl  _man  _null
Module  string      _tcl  _man  _null
Module  stringprep  _tcl  _man  _null
Module  struct      _tcl  _man _exa
Module  tar         _tcl  _man  _null
Module  tepam       _tcl  _man  _exa
Module  term         _tcr _man _exa
Module  textutil     _tex _man  _null
Module  tie         _tcl  _man  _exa
Module  tiff        _tcl  _man  _null
Module  tool        _tcl  _man  _null
Module  tool_datatype        _tcl  _man  _null
Module  transfer    _tcl  _man  _null
Module  treeql      _tcl  _man  _null
Module  try         _tcl  _man  _null
Module  uev         _tcl  _man  _null
Module  units       _tcl  _man  _null
Module  uri         _tcl  _man  _null
Module  uuid        _tcl  _man  _null
Module  valtype     _tcl _null  _null
Module  virtchannel_base       _tcl _man  _null
Module  virtchannel_core       _tcl _man  _null
Module  virtchannel_transform  _tcl _man  _null
Module  websocket   _tcl  _man  _null
Module  wip         _tcl  _man  _null
Module  yaml        _tcl  _man  _null
Module  zip        _tcl  _null  _null

Application  dtplite
Application  nns
Application  nnsd
Application  nnslog
Application  page
Application  pt
Application  tcldocstrip

# @@ Registration END
# --------------------------------------------------------------
