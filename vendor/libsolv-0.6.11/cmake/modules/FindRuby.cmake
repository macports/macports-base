# - Find Ruby
# This module finds if Ruby is installed and determines where the include files
# and libraries are. Ruby 1.8 and 1.9 are supported.
#
# The minimum required version of Ruby can be specified using the
# standard syntax, e.g. FIND_PACKAGE(Ruby 1.8)
#
# It also determines what the name of the library is. This
# code sets the following variables:
#
#  RUBY_EXECUTABLE   = full path to the ruby binary
#  RUBY_INCLUDE_DIRS = include dirs to be used when using the ruby library
#  RUBY_LIBRARY      = full path to the ruby library
#  RUBY_VERSION      = the version of ruby which was found, e.g. "1.8.7"
#  RUBY_FOUND        = set to true if ruby ws found successfully
#
#  RUBY_INCLUDE_PATH = same as RUBY_INCLUDE_DIRS, only provided for compatibility reasons, don't use it

#=============================================================================
# Copyright 2004-2009 Kitware, Inc.
# Copyright 2008-2009 Alexander Neundorf <neundorf@kde.org>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# * Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.
#
# * Neither the names of Kitware, Inc., the Insight Software Consortium,
#   nor the names of their contributors may be used to endorse or promote
#   products derived from this software without specific prior written
#   permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#=============================================================================

#   RUBY_ARCHDIR=`$RUBY -r rbconfig -e 'printf("%s",Config::CONFIG@<:@"archdir"@:>@)'`
#   RUBY_SITEARCHDIR=`$RUBY -r rbconfig -e 'printf("%s",Config::CONFIG@<:@"sitearchdir"@:>@)'`
#   RUBY_SITEDIR=`$RUBY -r rbconfig -e 'printf("%s",Config::CONFIG@<:@"sitelibdir"@:>@)'`
#   RUBY_LIBDIR=`$RUBY -r rbconfig -e 'printf("%s",Config::CONFIG@<:@"libdir"@:>@)'`
#   RUBY_LIBRUBYARG=`$RUBY -r rbconfig -e 'printf("%s",Config::CONFIG@<:@"LIBRUBYARG_SHARED"@:>@)'`

# uncomment the following line to get debug output for this file
# SET(_RUBY_DEBUG_OUTPUT TRUE)

# Determine the list of possible names of the ruby executable depending
# on which version of ruby is required
SET(_RUBY_POSSIBLE_EXECUTABLE_NAMES ruby)

# if 1.9 is required, don't look for ruby18 and ruby1.8, default to version 1.8
IF(Ruby_FIND_VERSION_MAJOR  AND  Ruby_FIND_VERSION_MINOR)
   SET(Ruby_FIND_VERSION_SHORT_NODOT "${Ruby_FIND_VERSION_MAJOR}${RUBY_FIND_VERSION_MINOR}")
ELSE(Ruby_FIND_VERSION_MAJOR  AND  Ruby_FIND_VERSION_MINOR)
   SET(Ruby_FIND_VERSION_SHORT_NODOT "18")
ENDIF(Ruby_FIND_VERSION_MAJOR  AND  Ruby_FIND_VERSION_MINOR)

SET(_RUBY_POSSIBLE_EXECUTABLE_NAMES ${_RUBY_POSSIBLE_EXECUTABLE_NAMES} ruby1.9 ruby19)

# if we want a version below 1.9, also look for ruby 1.8
IF("${Ruby_FIND_VERSION_SHORT_NODOT}" VERSION_LESS "19")
   SET(_RUBY_POSSIBLE_EXECUTABLE_NAMES ${_RUBY_POSSIBLE_EXECUTABLE_NAMES} ruby1.8 ruby18)
ENDIF("${Ruby_FIND_VERSION_SHORT_NODOT}" VERSION_LESS "19")

FIND_PROGRAM(RUBY_EXECUTABLE NAMES ${_RUBY_POSSIBLE_EXECUTABLE_NAMES})


IF(RUBY_EXECUTABLE  AND NOT  RUBY_VERSION_MAJOR)
  FUNCTION(_RUBY_CONFIG_VAR RBVAR OUTVAR)
    EXECUTE_PROCESS(COMMAND ${RUBY_EXECUTABLE} -r rbconfig -e "print RbConfig::CONFIG['${RBVAR}']"
      RESULT_VARIABLE _RUBY_SUCCESS
      OUTPUT_VARIABLE _RUBY_OUTPUT
      ERROR_QUIET)
    IF(_RUBY_SUCCESS OR NOT _RUBY_OUTPUT)
      EXECUTE_PROCESS(COMMAND ${RUBY_EXECUTABLE} -r rbconfig -e "print Config::CONFIG['${RBVAR}']"
        RESULT_VARIABLE _RUBY_SUCCESS
        OUTPUT_VARIABLE _RUBY_OUTPUT
        ERROR_QUIET)
    ENDIF(_RUBY_SUCCESS OR NOT _RUBY_OUTPUT)
    SET(${OUTVAR} "${_RUBY_OUTPUT}" PARENT_SCOPE)
  ENDFUNCTION(_RUBY_CONFIG_VAR)


  # query the ruby version
   _RUBY_CONFIG_VAR("MAJOR" RUBY_VERSION_MAJOR)
   _RUBY_CONFIG_VAR("MINOR" RUBY_VERSION_MINOR)
   _RUBY_CONFIG_VAR("TEENY" RUBY_VERSION_PATCH)

   # query the different directories
   _RUBY_CONFIG_VAR("archdir" RUBY_ARCH_DIR)
   _RUBY_CONFIG_VAR("arch" RUBY_ARCH)
   _RUBY_CONFIG_VAR("rubyhdrdir" RUBY_HDR_DIR)
   _RUBY_CONFIG_VAR("libdir" RUBY_POSSIBLE_LIB_DIR)
   _RUBY_CONFIG_VAR("rubylibdir" RUBY_RUBY_LIB_DIR)

   # site_ruby
   _RUBY_CONFIG_VAR("sitearchdir" RUBY_SITEARCH_DIR)
   _RUBY_CONFIG_VAR("sitelibdir" RUBY_SITELIB_DIR)

   # vendor_ruby available ?
   EXECUTE_PROCESS(COMMAND ${RUBY_EXECUTABLE} -r rbconfig -e "print 'true' unless RbConfig::CONFIG['vendorarchdir'].nil?"
      OUTPUT_VARIABLE RUBY_HAS_VENDOR_RUBY  ERROR_QUIET)

   IF(RUBY_HAS_VENDOR_RUBY)
      _RUBY_CONFIG_VAR("vendorlibdir" RUBY_VENDORLIB_DIR)
      _RUBY_CONFIG_VAR("vendorarchdir" RUBY_VENDORARCH_DIR)
   ENDIF(RUBY_HAS_VENDOR_RUBY)

   # save the results in the cache so we don't have to run ruby the next time again
   SET(RUBY_VERSION_MAJOR    ${RUBY_VERSION_MAJOR}    CACHE PATH "The Ruby major version" FORCE)
   SET(RUBY_VERSION_MINOR    ${RUBY_VERSION_MINOR}    CACHE PATH "The Ruby minor version" FORCE)
   SET(RUBY_VERSION_PATCH    ${RUBY_VERSION_PATCH}    CACHE PATH "The Ruby patch version" FORCE)
   SET(RUBY_ARCH_DIR         ${RUBY_ARCH_DIR}         CACHE PATH "The Ruby arch dir" FORCE)
   SET(RUBY_HDR_DIR          ${RUBY_HDR_DIR}          CACHE PATH "The Ruby header dir (1.9)" FORCE)
   SET(RUBY_POSSIBLE_LIB_DIR ${RUBY_POSSIBLE_LIB_DIR} CACHE PATH "The Ruby lib dir" FORCE)
   SET(RUBY_RUBY_LIB_DIR     ${RUBY_RUBY_LIB_DIR}     CACHE PATH "The Ruby ruby-lib dir" FORCE)
   SET(RUBY_SITEARCH_DIR     ${RUBY_SITEARCH_DIR}     CACHE PATH "The Ruby site arch dir" FORCE)
   SET(RUBY_SITELIB_DIR      ${RUBY_SITELIB_DIR}      CACHE PATH "The Ruby site lib dir" FORCE)
   SET(RUBY_HAS_VENDOR_RUBY  ${RUBY_HAS_VENDOR_RUBY}  CACHE BOOL "Vendor Ruby is available" FORCE)
   SET(RUBY_VENDORARCH_DIR   ${RUBY_VENDORARCH_DIR}   CACHE PATH "The Ruby vendor arch dir" FORCE)
   SET(RUBY_VENDORLIB_DIR    ${RUBY_VENDORLIB_DIR}    CACHE PATH "The Ruby vendor lib dir" FORCE)

   MARK_AS_ADVANCED(
     RUBY_ARCH_DIR
     RUBY_ARCH
     RUBY_HDR_DIR
     RUBY_POSSIBLE_LIB_DIR
     RUBY_RUBY_LIB_DIR
     RUBY_SITEARCH_DIR
     RUBY_SITELIB_DIR
     RUBY_HAS_VENDOR_RUBY
     RUBY_VENDORARCH_DIR
     RUBY_VENDORLIB_DIR
     RUBY_VERSION_MAJOR
     RUBY_VERSION_MINOR
     RUBY_VERSION_PATCH
     )
ENDIF(RUBY_EXECUTABLE  AND NOT  RUBY_VERSION_MAJOR)

# In case RUBY_EXECUTABLE could not be executed (e.g. cross compiling)
# try to detect which version we found. This is not too good.
IF(RUBY_EXECUTABLE AND NOT RUBY_VERSION_MAJOR)
   # by default assume 1.8.0
   SET(RUBY_VERSION_MAJOR 1)
   SET(RUBY_VERSION_MINOR 8)
   SET(RUBY_VERSION_PATCH 0)
   # check whether we found 1.9.x
   IF(${RUBY_EXECUTABLE} MATCHES "ruby1.?9"  OR  RUBY_HDR_DIR)
      SET(RUBY_VERSION_MAJOR 1)
      SET(RUBY_VERSION_MINOR 9)
   ENDIF(${RUBY_EXECUTABLE} MATCHES "ruby1.?9"  OR  RUBY_HDR_DIR)
ENDIF(RUBY_EXECUTABLE AND NOT RUBY_VERSION_MAJOR)

IF(RUBY_VERSION_MAJOR)
   SET(RUBY_VERSION "${RUBY_VERSION_MAJOR}.${RUBY_VERSION_MINOR}.${RUBY_VERSION_PATCH}")
   SET(_RUBY_VERSION_SHORT "${RUBY_VERSION_MAJOR}.${RUBY_VERSION_MINOR}")
   SET(_RUBY_VERSION_SHORT_NODOT "${RUBY_VERSION_MAJOR}${RUBY_VERSION_MINOR}")
   SET(_RUBY_NODOT_VERSION "${RUBY_VERSION_MAJOR}${RUBY_VERSION_MINOR}${RUBY_VERSION_PATCH}")
ENDIF(RUBY_VERSION_MAJOR)

FIND_PATH(RUBY_INCLUDE_DIR
   NAMES ruby.h
   HINTS
   ${RUBY_HDR_DIR}
   ${RUBY_ARCH_DIR}
   /usr/lib/ruby/${_RUBY_VERSION_SHORT}/i586-linux-gnu/ )

SET(RUBY_INCLUDE_DIRS ${RUBY_INCLUDE_DIR} )

# if ruby > 1.8 is required or if ruby > 1.8 was found, search for the config.h dir
IF( "${Ruby_FIND_VERSION_SHORT_NODOT}" GREATER 18  OR  "${_RUBY_VERSION_SHORT_NODOT}" GREATER 18  OR  RUBY_HDR_DIR)
   FIND_PATH(RUBY_CONFIG_INCLUDE_DIR
     NAMES ruby/config.h  config.h
     HINTS
     ${RUBY_HDR_DIR}/${RUBY_ARCH}
     ${RUBY_ARCH_DIR}
     )

   SET(RUBY_INCLUDE_DIRS ${RUBY_INCLUDE_DIRS} ${RUBY_CONFIG_INCLUDE_DIR} )
ENDIF( "${Ruby_FIND_VERSION_SHORT_NODOT}" GREATER 18  OR  "${_RUBY_VERSION_SHORT_NODOT}" GREATER 18  OR  RUBY_HDR_DIR)


# Determine the list of possible names for the ruby library
SET(_RUBY_POSSIBLE_LIB_NAMES ruby ruby-static ruby${_RUBY_VERSION_SHORT} ruby${_RUBY_VERSION_SHORT_NODOT} ruby-${_RUBY_VERSION_SHORT} ruby-${RUBY_VERSION})

IF(WIN32)
   SET( _RUBY_MSVC_RUNTIME "" )
   IF( MSVC60 )
     SET( _RUBY_MSVC_RUNTIME "60" )
   ENDIF( MSVC60 )
   IF( MSVC70 )
     SET( _RUBY_MSVC_RUNTIME "70" )
   ENDIF( MSVC70 )
   IF( MSVC71 )
     SET( _RUBY_MSVC_RUNTIME "71" )
   ENDIF( MSVC71 )
   IF( MSVC80 )
     SET( _RUBY_MSVC_RUNTIME "80" )
   ENDIF( MSVC80 )
   IF( MSVC90 )
     SET( _RUBY_MSVC_RUNTIME "90" )
   ENDIF( MSVC90 )

   LIST(APPEND _RUBY_POSSIBLE_LIB_NAMES
               "msvcr${_RUBY_MSVC_RUNTIME}-ruby${_RUBY_NODOT_VERSION}"
               "msvcr${_RUBY_MSVC_RUNTIME}-ruby${_RUBY_NODOT_VERSION}-static"
               "msvcrt-ruby${_RUBY_NODOT_VERSION}"
               "msvcrt-ruby${_RUBY_NODOT_VERSION}-static" )
ENDIF(WIN32)

FIND_LIBRARY(RUBY_LIBRARY NAMES ${_RUBY_POSSIBLE_LIB_NAMES} HINTS ${RUBY_POSSIBLE_LIB_DIR} )

INCLUDE(FindPackageHandleStandardArgs)
SET(_RUBY_REQUIRED_VARS RUBY_EXECUTABLE RUBY_INCLUDE_DIR RUBY_LIBRARY)
IF(_RUBY_VERSION_SHORT_NODOT GREATER 18)
   LIST(APPEND _RUBY_REQUIRED_VARS RUBY_CONFIG_INCLUDE_DIR)
ENDIF(_RUBY_VERSION_SHORT_NODOT GREATER 18)

IF(_RUBY_DEBUG_OUTPUT)
   MESSAGE(STATUS "--------FindRuby.cmake debug------------")
   MESSAGE(STATUS "_RUBY_POSSIBLE_EXECUTABLE_NAMES: ${_RUBY_POSSIBLE_EXECUTABLE_NAMES}")
   MESSAGE(STATUS "_RUBY_POSSIBLE_LIB_NAMES: ${_RUBY_POSSIBLE_LIB_NAMES}")
   MESSAGE(STATUS "RUBY_ARCH_DIR: ${RUBY_ARCH_DIR}")
   MESSAGE(STATUS "RUBY_HDR_DIR: ${RUBY_HDR_DIR}")
   MESSAGE(STATUS "RUBY_POSSIBLE_LIB_DIR: ${RUBY_POSSIBLE_LIB_DIR}")
   MESSAGE(STATUS "Found RUBY_VERSION: \"${RUBY_VERSION}\" , short: \"${_RUBY_VERSION_SHORT}\", nodot: \"${_RUBY_VERSION_SHORT_NODOT}\"")
   MESSAGE(STATUS "_RUBY_REQUIRED_VARS: ${_RUBY_REQUIRED_VARS}")
   MESSAGE(STATUS "RUBY_EXECUTABLE: ${RUBY_EXECUTABLE}")
   MESSAGE(STATUS "RUBY_LIBRARY: ${RUBY_LIBRARY}")
   MESSAGE(STATUS "RUBY_INCLUDE_DIR: ${RUBY_INCLUDE_DIR}")
   MESSAGE(STATUS "RUBY_CONFIG_INCLUDE_DIR: ${RUBY_CONFIG_INCLUDE_DIR}")
   MESSAGE(STATUS "--------------------")
ENDIF(_RUBY_DEBUG_OUTPUT)

FIND_PACKAGE_HANDLE_STANDARD_ARGS(Ruby  REQUIRED_VARS  ${_RUBY_REQUIRED_VARS}
                                        VERSION_VAR RUBY_VERSION )

MARK_AS_ADVANCED(
  RUBY_EXECUTABLE
  RUBY_LIBRARY
  RUBY_INCLUDE_DIR
  RUBY_CONFIG_INCLUDE_DIR
  )

# Set some variables for compatibility with previous version of this file
SET(RUBY_POSSIBLE_LIB_PATH ${RUBY_POSSIBLE_LIB_DIR})
SET(RUBY_RUBY_LIB_PATH ${RUBY_RUBY_LIB_DIR})
SET(RUBY_INCLUDE_PATH ${RUBY_INCLUDE_DIRS})
