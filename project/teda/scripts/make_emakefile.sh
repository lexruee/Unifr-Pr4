#!/bin/bash
# Creates an Emakefile in the directory from where this script is executed.
#
# History: Christian Göttel, 11.04.2014, adaped for new scripts
#
# Author: Daniel Weibel, 26.07.2013, <daniel.weibel@unifr.ch>
# Last modified: 11.04.2014
# ---------------------------------------------------------------------------- #

# Note 1: the compiler option no_line_info is to make object code created by a
# R16 compiler compatible with a R13 virtual machine. It avoids that the object
# code contains the opcode 153 which is not known by R13 VMs.
# This is just a workaround due to our specific settings (Erlang R13 on DIUF
# Linux machines and Erlang R16 on most personal machines), and it can be
# adapted for different settings.

# Note 2: this Emakefile is supposed to be used by every Erlang TEDA app. It
# means, compile everything in the current directory, and everything in the
# lib directory. That's basically everything that a TEDA app needs to run.

cat > Emakefile << EOF
{'*', [no_line_info]}.
{'../../lib/*', [no_line_info]}.
EOF

# echo "{'*', [no_line_info]}." > $EMAKEFILE
# echo "{'${PATH_TO_LIB}/*', [no_line_info]}." >> $EMAKEFILE