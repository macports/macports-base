# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# $Id$

# Create Portfile
#
# Workflow:
# 1. Gather metadata
# 2. Feed template
# 3. Print result

set fp [open "Portfile.template" r]
set template [read $fp]
close $fp

puts $template
