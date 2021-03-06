#!/bin/bash
# Use this script to build MegaGlest Installer for a Version Release
# ----------------------------------------------------------------------------
# Written by Mark Vejvoda <mark_vejvoda@hotmail.com>
# Copyright (c) 2011 Mark Vejvoda under GNU GPL v3.0+


# This script is not robust for all platforms or situations. Use as a rough
#  example, but invest effort in what it's trying to do, and what it produces.
#  (make sure you don't build in features you don't need, etc).

# To install the installer silently you may run it like this:
# ./megaglest-installer.run --noprompt --i-agree-to-all-licenses --destination /home/softcoder/megaglest-temp-test --noreadme --ui=stdio

# below is the branch to build and installer from.

# Consider setting this for small packages if there's plenty of RAM and CPU available:
#export XZ_OPT="$XZ_OPT -9e"

megaglest_release_folder=""
#megaglest_release_folder="trunk"
#megaglest_release_folder="release-3.3.5.1"

CURRENTDIR="$(dirname $(readlink -f $0))"
# below describe various folder paths relative to the installer root folder
#megaglest_project_root=../../../../../
megaglest_project_root=../../../../
megaglest_data_path=${megaglest_project_root}${megaglest_release_folder}/data/glest_game/
megaglest_linux_path=${megaglest_project_root}${megaglest_release_folder}/mk/linux/
megaglest_linux_masterserverpath=${megaglest_project_root}${megaglest_release_folder}/source/masterserver/
megaglest_linux_toolspath=${megaglest_project_root}${megaglest_release_folder}/source/tools/

VERSION=`$CURRENTDIR/${megaglest_linux_path}/mg-version.sh --version`
kernel=`uname -s | tr '[A-Z]' '[a-z]'`
architecture=`uname -m  | tr '[A-Z]' '[a-z]'`
mg_installer_bin_name=MegaGlest-Installer-${VERSION}_${architecture}_${kernel}.run
#echo $mg_installer_bin_name
#exit 1

if which zip >/dev/null; then
    echo Compression tool 'zip' exists
else
    echo Compression tool 'zip' DOES NOT EXIST on this system, please install it
    exit 1
fi

if which xz >/dev/null; then
    echo Compression tool 'xz' exists
else
    echo Compression tool 'xz' DOES NOT EXIST on this system, please install it
    exit 1
fi

if which tar >/dev/null; then
    echo Compression tool 'tar' exists
else
    echo Compression tool 'tar' DOES NOT EXIST on this system, please install it
    exit 1
fi

# Below is the name of the archive to create and tack onto the installer.
# *NOTE: The filename's extension is of critical importance as the installer
# does a patch on extension to figure out how to decompress!
#
# static const MojoArchiveType archives[] =
# {
#    { "zip", MojoArchive_createZIP, true },
#    { "tar", MojoArchive_createTAR, true },
#    { "tar.gz", MojoArchive_createTAR, true },
#    { "tar.bz2", MojoArchive_createTAR, true },
#    { "tgz", MojoArchive_createTAR, true },
#    { "tbz2", MojoArchive_createTAR, true },
#    { "tb2", MojoArchive_createTAR, true },
#    { "tbz", MojoArchive_createTAR, true },
#    { "uz2", MojoArchive_createUZ2, false },
#    { "pck", MojoArchive_createPCK, true },
#    { "tar.xz", MojoArchive_createTAR, true },
#    { "txz", MojoArchive_createTAR, true },
# };
#
#megaglest_archiver_app_data='tar -cf - * | xz > mgdata.tar.xz'
megaglest_archivefilename_data="mgdata.tar.xz"

#megaglest_archiver_app="zip -9r "
#megaglest_archivefilename="mgdata.zip"
megaglest_archiver_app="zip -0r "
megaglest_archivefilename="mgpkg.zip"
#megaglest_archiver_app="tar -c --bzip2 -f "
#megaglest_archivefilename="mgdata.tar.bz2"

# Grab the version #
#
echo "Linux project root path [$CURRENTDIR/${megaglest_linux_path}]"

echo "About to build Installer for $VERSION"
# Stop if anything produces an error.
set -e

REPACKONLY=0
DEBUG=0
if [ "$1" = "--debug" -o "$2" = "--debug" ]; then
    echo "debug build!"
    DEBUG=1
fi
if [ "$1" = "--repackonly" -o "$2" = "--repackonly" ]; then
    echo "repacking installer only!"
    REPACKONLY=1
fi

APPNAME="MegaGlest Installer"

# I use a "cross compiler" to build binaries that are isolated from the
#  particulars of my Linux workstation's current distribution. This both
#  keeps me at a consistent ABI for generated binaries and prevent subtle
#  dependencies from leaking in.
# You may not care about this at all. In which case, just use the
#  CC=gcc and CXX=g++ lines instead.
CC=/usr/bin/gcc
CXX=/usr/bin/g++
#CC=/opt/crosstool/gcc-3.3.6-glibc-2.3.5/i686-unknown-linux-gnu/i686-unknown-linux-gnu/bin/gcc
#CXX=/opt/crosstool/gcc-3.3.6-glibc-2.3.5/i686-unknown-linux-gnu/i686-unknown-linux-gnu/bin/g++

OSTYPE=`uname -s`
if [ "$OSTYPE" = "Linux" ]; then
    NCPU=`lscpu -p | grep -cv '^#'`
    if [ "$NUMCORES" = '' ]; then NUMCORES=1; fi
elif [ "$OSTYPE" = "Darwin" ]; then
    NCPU=`sysctl -n hw.ncpu`
elif [ "$OSTYPE" = "SunOS" ]; then
    NCPU=`/usr/sbin/psrinfo |wc -l |sed -e 's/^ *//g;s/ *$//g'`
else
    NCPU=1
fi

if [ "x$NCPU" = "x" ]; then
    NCPU=1
fi
if [ "x$NCPU" = "x0" ]; then
    NCPU=1
fi

echo "Will use make -j$NCPU. If this is wrong, check NCPU at top of script."

# Show everything that we do here on stdout.
set -x

if [ "$DEBUG" = "1" ]; then
    LUASTRIPOPT=
    BUILDTYPE=Debug
    TRUEIFDEBUG=TRUE
    FALSEIFDEBUG=FALSE
else
    LUASTRIPOPT=-s
    BUILDTYPE=MinSizeRel
    TRUEIFDEBUG=FALSE
    FALSEIFDEBUG=TRUE
fi

# Clean up previous run, build fresh dirs for Base Archive.
rm -rf image ${mg_installer_bin_name} ${megaglest_archivefilename}
mkdir image
mkdir image/guis
mkdir image/scripts
mkdir image/data
mkdir image/meta

# This next section copies live data from the MegaGlest directories
if [ $REPACKONLY -eq 0 ]; then

	rm -rf data
	mkdir data
	mkdir data/blender

	INSTALL_ROOTDIR=$CURRENTDIR/
	INSTALLDATADIR="${INSTALL_ROOTDIR}data/"

	# Now copy all megaglest binaries
	echo Copying live MegaGlest binary files...

	cp "$CURRENTDIR/$megaglest_linux_path/start_megaglest" $INSTALLDATADIR
	cp "$CURRENTDIR/$megaglest_linux_path/megaglest" ${INSTALLDATADIR}
	cp "$CURRENTDIR/$megaglest_linux_path/glest.ini" $INSTALLDATADIR
	cp "$CURRENTDIR/$megaglest_linux_path/megaglest.bmp" $INSTALLDATADIR
	cp "$CURRENTDIR/$megaglest_linux_path/glestkeys.ini" $INSTALLDATADIR
#        cp "$CURRENTDIR/$megaglest_linux_path/start_megaglest_configurator" $INSTALLDATADIR
#	cp "$CURRENTDIR/$megaglest_linux_path/megaglest_configurator" ${INSTALLDATADIR}
        cp "$CURRENTDIR/$megaglest_linux_path/start_megaglest_mapeditor" $INSTALLDATADIR
	cp "$CURRENTDIR/$megaglest_linux_path/megaglest_editor" ${INSTALLDATADIR}
        cp "$CURRENTDIR/$megaglest_linux_path/start_megaglest_g3dviewer" $INSTALLDATADIR
	cp "$CURRENTDIR/$megaglest_linux_path/megaglest_g3dviewer" ${INSTALLDATADIR}
	cp "$CURRENTDIR/$megaglest_linux_path/servers.ini" $INSTALLDATADIR
	cp "$CURRENTDIR/$megaglest_linux_path/makedeps_folder.sh" $INSTALL_ROOTDIR

	# Now copy all blender related files
	echo Copying blender modelling MegaGlest files...

	svn export --force "$CURRENTDIR/${megaglest_linux_toolspath}/glexemel/" "${INSTALLDATADIR}blender/"

	# Now copy all glest data
	echo Copying live MegaGlest data files...

#	cp "$CURRENTDIR/$megaglest_data_path/configuration.xml" $INSTALLDATADIR
	cp "$CURRENTDIR/$megaglest_data_path/megaglest.ico" $INSTALLDATADIR
	cp "$CURRENTDIR/$megaglest_data_path/megaglest_uninstall.ico" $INSTALLDATADIR
	cp "$CURRENTDIR/$megaglest_data_path/g3dviewer.ico" ${INSTALLDATADIR}
	cp "$CURRENTDIR/$megaglest_data_path/editor.ico" ${INSTALLDATADIR}

	mkdir -p "$INSTALLDATADIR/data/"
	svn export --force "$CURRENTDIR/$megaglest_data_path/data/" "$INSTALLDATADIR/data/"
	mkdir -p "$INSTALLDATADIR/docs/"
	svn export --force "$CURRENTDIR/$megaglest_data_path/docs/" "$INSTALLDATADIR/docs/"
	svn export --force "${megaglest_project_root}${megaglest_release_folder}/docs/" "$INSTALLDATADIR/docs/"
	mkdir -p "$INSTALLDATADIR/maps/"
	svn export --force "$CURRENTDIR/$megaglest_data_path/maps/" "$INSTALLDATADIR/maps/"
	mkdir -p "$INSTALLDATADIR/scenarios/"
	svn export --force "$CURRENTDIR/$megaglest_data_path/scenarios/" "$INSTALLDATADIR/scenarios/"
	mkdir -p "$INSTALLDATADIR/techs/"
	svn export --force "$CURRENTDIR/$megaglest_data_path/techs/" "$INSTALLDATADIR/techs/"
	mkdir -p "$INSTALLDATADIR/tilesets/"
	svn export --force "$CURRENTDIR/$megaglest_data_path/tilesets/" "$INSTALLDATADIR/tilesets/"
	mkdir -p "$INSTALLDATADIR/tutorials/"
	svn export --force "$CURRENTDIR/$megaglest_data_path/tutorials/" "$INSTALLDATADIR/tutorials/"

	# Now copy all megaglest data
	echo Copying live MegaGlest country logo files...

	mkdir -p "${INSTALLDATADIR}data/core/misc_textures/"
	svn export --force "$CURRENTDIR/$megaglest_linux_masterserverpath/flags/" "${INSTALLDATADIR}data/core/misc_textures/flags/"

	# Copy shared lib dependencies for megaglest
	cd data
	copyGlestDeptsCmd="${INSTALL_ROOTDIR}makedeps_folder.sh megaglest"
	$copyGlestDeptsCmd

	LIBVLC_DIR=`ldd megaglest | grep "libvlc\." | sort -u | awk '{print $3}' | xargs dirname`
	echo LibVLC installed in [$LIBVLC_DIR]
	cp -r $LIBVLC_DIR/vlc lib/
	#exit 1

	cd ..
fi

if [ ! -d data/docs ]; then
    echo "We don't see data/docs ..."
    echo " Either you're in the wrong directory, or you didn't copy the"
    echo " install data into here (it's unreasonably big to store it in"
    echo " revision control for no good reason)."
    exit 1
fi


# Build MojoSetup binaries from scratch.
# YOU ALWAYS NEED THE LUA PARSER IF YOU WANT UNINSTALL SUPPORT!
cd ../
rm -rf cmake-build
mkdir cmake-build
cd cmake-build
cmake \
    -DCMAKE_BUILD_TYPE=$BUILDTYPE \
    -DCMAKE_C_COMPILER=$CC \
    -DCMAKE_CXX_COMPILER=$CXX \
    -DMOJOSETUP_MULTIARCH=FALSE \
    -DMOJOSETUP_ARCHIVE_ZIP=TRUE \
    -DMOJOSETUP_ARCHIVE_TAR=TRUE \
    -DMOJOSETUP_ARCHIVE_TAR_BZ2=TRUE \
    -DMOJOSETUP_ARCHIVE_TAR_GZ=TRUE \
    -DMOJOSETUP_ARCHIVE_TAR_XZ=TRUE \
    -DMOJOSETUP_INPUT_XZ=TRUE \
    -DMOJOSETUP_INTERNAL_LIBLZMA=TRUE \
    -DMOJOSETUP_BUILD_LUAC=TRUE \
    -DMOJOSETUP_GUI_GTKPLUS2=TRUE \
    -DMOJOSETUP_GUI_GTKPLUS2_STATIC=TRUE \
    -DMOJOSETUP_GUI_NCURSES=TRUE \
    -DMOJOSETUP_GUI_NCURSES_STATIC=TRUE \
    -DMOJOSETUP_GUI_STDIO=TRUE \
    -DMOJOSETUP_GUI_STDIO_STATIC=TRUE \
    -DMOJOSETUP_GUI_WWW=FALSE \
    -DMOJOSETUP_GUI_WWW_STATIC=FALSE \
    -DMOJOSETUP_LUALIB_DB=FALSE \
    -DMOJOSETUP_LUALIB_IO=TRUE \
    -DMOJOSETUP_LUALIB_MATH=FALSE \
    -DMOJOSETUP_LUALIB_OS=TRUE \
    -DMOJOSETUP_LUALIB_PACKAGE=TRUE \
    -DMOJOSETUP_LUA_PARSER=TRUE \
    -DMOJOSETUP_IMAGE_BMP=TRUE \
    -DMOJOSETUP_IMAGE_JPG=FALSE \
    -DMOJOSETUP_IMAGE_PNG=FALSE \
    -DMOJOSETUP_INTERNAL_BZLIB=TRUE \
    -DMOJOSETUP_INTERNAL_ZLIB=TRUE \
    -DMOJOSETUP_URL_HTTP=FALSE \
    -DMOJOSETUP_URL_FTP=FALSE \
    ..

# Perhaps needed to remove compiler / linker warnings considered as errors
# sed -i 's/-Werror//' Makefile

make -j$NCPU

# Strip the binaries and GUI plugins, put them somewhere useful.
if [ "$DEBUG" != "1" ]; then
    strip ./mojosetup
fi

mv ./mojosetup ../megaglest-installer/${mg_installer_bin_name}
for feh in *.so *.dll *.dylib ; do
    if [ -f $feh ]; then
        if [ "$DEBUG" != "1" ]; then
            strip $feh
        fi
        mv $feh ../megaglest-installer/image/guis
    fi
done

# Compile the Lua scripts, put them in the base archive.
for feh in ../scripts/*.lua ; do
    ./mojoluac $LUASTRIPOPT -o ../megaglest-installer/image/scripts/${feh}c $feh
done

# Don't want the example config...use our's instead.
rm -f ../megaglest-installer/image/scripts/config.luac
./mojoluac $LUASTRIPOPT -o ../megaglest-installer/image/scripts/config.luac ../megaglest-installer/scripts/config.lua

# Don't want the example app_localization...use our's instead.
rm -f ../megaglest-installer/image/scripts/app_localization.luac
./mojoluac $LUASTRIPOPT -o ../megaglest-installer/image/scripts/app_localization.luac ../megaglest-installer/scripts/app_localization.lua

# Fill in the rest of the Base Archive...
cd ../megaglest-installer

# Compress the main data archive
cd data
#${megaglest_archiver_app_data} ${megaglest_archivefilename_data}
tar -cf - * | xz > $megaglest_archivefilename_data
# now remove everything except for the docs folder and the data archive
shopt -s extglob
rm -rf !(docs|$megaglest_archivefilename_data)
cd ..

cp -R data/* image/data/
cp meta/* image/meta/

# Need these scripts to do things like install menu items, etc, on Unix.
if [ "$OSTYPE" = "Linux" ]; then
    USE_XDG_UTILS=1
fi
if [ "$OSTYPE" = "SunOS" ]; then
    USE_XDG_UTILS=1
fi

if [ "x$USE_XDG_UTILS" = "x1" ]; then
    mkdir image/meta/xdg-utils
    cp ../meta/xdg-utils/* image/meta/xdg-utils/
    chmod a+rx image/meta/xdg-utils/*
fi

if [ "$OSTYPE" = "Darwin" ]; then
    # Build up the application bundle for Mac OS X...
    APPBUNDLE="$APPNAME.app"
    rm -rf "$APPBUNDLE"
    cp -Rv ../misc/MacAppBundleSkeleton "$APPBUNDLE"
	perl -w -pi -e 's/YOUR_APPLICATION_NAME_HERE/'"$APPNAME"'/g;' "${APPBUNDLE}/Contents/Info.plist"
    mv megaglest-installer "${APPBUNDLE}/Contents/MacOS/mojosetup"
    mv image/* "${APPBUNDLE}/Contents/MacOS/"
    rmdir image
    ibtool --compile "${APPBUNDLE}/Contents/Resources/MojoSetup.nib" ../misc/MojoSetup.xib
else

    # Make an archive of the Base Archive dirs and nuke the originals...
    cd image

# create the compressed image for the installer (this will use zip as a container)
#    zip -9r ../${megaglest_archivefilename} *
    ${megaglest_archiver_app} ../${megaglest_archivefilename} *

    cd ..
    rm -rf image
    # Append the archive to the mojosetup binary, so it's "self-extracting."
    cat ${megaglest_archivefilename} >> ./${mg_installer_bin_name}
    rm -f ${megaglest_archivefilename}
fi

# ...and that's that.
set +e
set +x
echo "Successfully built!"
ls -la ${mg_installer_bin_name}

if [ "$DEBUG" = "1" ]; then
    echo
    echo
    echo
    echo 'ATTENTION: THIS IS A DEBUG BUILD!'
    echo " DON'T DISTRIBUTE TO THE PUBLIC."
    echo ' THIS IS PROBABLY BIGGER AND SLOWER THAN IT SHOULD BE.'
    echo ' YOU HAVE BEEN WARNED!'
    echo
    echo
    echo
fi

exit 0

