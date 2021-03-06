#!/bin/sh
#
# Use this script to install build dependencies on a number of Linux platforms
# ----------------------------------------------------------------------------
# Originally written by Mark Vejvoda <mark_vejvoda@hotmail.com>
# Rewritten by Tom Reynolds <tomreyn@megaglest.org>
# Copyright (c) 2012 Mark Vejvoda, Tom Reynolds under GNU GPL v3.0

echo 'Downloading Javascript libraries...'
wget http://code.jquery.com/jquery-1.5.2.js -O media/jquery-1.5.min.js
wget http://www.datatables.net/download/build/jquery.dataTables.min.js -O media/jquery.dataTables.min.js

echo 'Installing dependencies...'
# This should actually use /etc/issue
if [ -f /etc/fedora-release ]; then
  echo 'Fedora...'
  #sudo yum groupinstall "Development Tools"
  #sudo yum install subversion automake autoconf autogen jam
elif [ -f /etc/SuSE-release ]; then
  echo '(Open)SuSE...'
  sudo zypper install graphviz-perl perl-GraphViz perl-Config-IniFiles perl-PerlMagick
elif [ -f /etc/debian_version ]; then
  echo 'Debian / Ubuntu...'
  sudo apt-get install perl graphviz libgraphviz-perl libconfig-inifiles-perl perlmagick
  #sudo apt-get install libimage-size-perl
else
  echo 'ERROR: Unknown distribution. Stopping here.' >&2
  exit 1
fi

echo ''
echo 'To run the techtree html builder edit mg.ini and run the script as follows:'
echo './convert_faction_xml2html.pl megapack.ini'
