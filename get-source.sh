#!/bin/sh
# Copyright 2015-2017  tde-slackbuilds project on GitHub
# All rights reserved.
#
#   Permission to use, copy, modify, and distribute this software for
#   any purpose with or without fee is hereby granted, provided that
#   the above copyright notice and this permission notice appear in all
#   copies.
#
#   THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESSED OR IMPLIED
#   WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#   MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
#   IN NO EVENT SHALL THE AUTHORS AND COPYRIGHT HOLDERS AND THEIR
#   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
#   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
#   USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#   ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
#   OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
#   OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
#   SUCH DAMAGE.

getsource_fn ()
{
#!/bin/sh
# Generated by Alien's SlackBuild Toolkit: http://slackware.com/~alien/AST
# Copyright 2009, 2010, 2011, 2012, 2013, 2014, 2015  Eric Hameleers, Eindhoven, Netherlands
# Copyright 2015-2017  Thorn Inurcide USA
# Copyright 2015-2017  tde-slackbuilds project on GitHub
# All rights reserved.
#
#   Permission to use, copy, modify, and distribute this software for
#   any purpose with or without fee is hereby granted, provided that
#   the above copyright notice and this permission notice appear in all
#   copies.
#
#   THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESSED OR IMPLIED
#   WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#   MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
#   IN NO EVENT SHALL THE AUTHORS AND COPYRIGHT HOLDERS AND THEIR
#   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
#   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
#   USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#   ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
#   OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
#   OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
#   SUCH DAMAGE.

# Place to build (TMP_BUILD) package (PKG) and output (OUTPUT) the program:
TMP_BUILD=/tmp/build
PKG=$TMP_BUILD/package-$PRGNAM
OUTPUT=/tmp

# remove any previous builds if option chosen
[[ $KEEP_BUILD != "yes" ]] && [[ $PRE_DOWNLOAD != yes ]] && echo -e "\n removing previous build data .." && rm -rf $TMP_BUILD/{tmp,package}*
# Only create working directories if building packages:
[[ $PRE_DOWNLOAD != yes ]] && {
mkdir -p $OUTPUT
mkdir -p $TMP_BUILD/tmp-$PRGNAM
mkdir -p $PKG
rm -rf $PKG/*
rm -rf $TMP_BUILD/tmp-$PRGNAM/*
rm -rf $OUTPUT/{checkout,configure,make,install,error,makepkg,patch}-$PRGNAM.log
}

# Where do we look for sources?
SRCDIR=$(cd $(dirname $0); pwd)

## if snapshot, need to change some variables:
[[ $TDEVERSION == r14.0.6 && ! $TDEMIR_SUBDIR == misc ]] && \
ARCHIVE_TYPE=tar.gz && \
SRCURL=https://mirror.git.trinitydesktop.org/cgit/$PRGNAM/snapshot/$PRGNAM-$TDEVERSION.$ARCHIVE_TYPE && \
(
## download admin/cmake/libltdl/libtdevnc as prerequisites
cd $SRCDIR/../../src/
echo 'admin
cmake
libltdl
libtdevnc' | while read line
do
[[ ! -s $line-$TDEVERSION.$ARCHIVE_TYPE && ! $line == libtdevnc ]] && \
wget https://mirror.git.trinitydesktop.org/cgit/$line/snapshot/$line-$TDEVERSION.$ARCHIVE_TYPE
[[ ! -s $line-r14.0.1.$ARCHIVE_TYPE && $line == libtdevnc ]] && \
wget https://mirror.git.trinitydesktop.org/cgit/$line/snapshot/$line-r14.0.1.$ARCHIVE_TYPE
done
)

## if [r]14.0.? or misc, download archive:
[[ $TDEVERSION == *14.0.? || $TDEMIR_SUBDIR == misc ]] && {
## check for and remove any zero byte archive files
[[ ! -s $SRCDIR/../../src/$PRGNAM-$VERSION.${ARCHIVE_TYPE:-"tar.xz"} ]] && \
rm $SRCDIR/../../src/$PRGNAM-$VERSION.${ARCHIVE_TYPE:-"tar.xz"} 2>/dev/null || true
## R14.0.6+ archive names include -trinity.
## To maintain compatibility with the previous naming convention,
## sym-link any pre-downloaded R14.0.6+ archives
[[ $TDEVERSION == 14.0.[6-9] ]] && [[ -s $SRCDIR/../../src/$PRGNAM-trinity-$VERSION.tar.xz ]] && \
(cd $SRCDIR/../../src/
ln -sf $PRGNAM-trinity-$VERSION.tar.xz $PRGNAM-$VERSION.tar.xz)

ln -sf $SRCDIR/../../src/$PRGNAM-$VERSION.${ARCHIVE_TYPE:-"tar.xz"} $SRCDIR
SOURCE=$SRCDIR/$PRGNAM-$VERSION.${ARCHIVE_TYPE:-"tar.xz"}
# SRCURL for non-TDE archives, set in the SB, will override the Trinity default *tar.xz URL
SRCURL=${SRCURL:-"https://$TDE_MIRROR/releases/R$VERSION/main$TDEMIR_SUBDIR/$PRGNAM-trinity-$VERSION.tar.xz"}
# Source file availability:
[[ -f $SOURCE ]] && [[ $PRE_DOWNLOAD == yes ]] && echo "  $(basename $SOURCE) already downloaded ..."

if ! [ -f $SOURCE ]; then
  echo "Source '$(basename $SOURCE)' not available yet..."
  # Check if the $SRCDIR is writable at all - if not, download to $OUTPUT
  [ -w "$SRCDIR" ] || SOURCE="$OUTPUT/$(basename $SOURCE)"
  if ! [ "x$SRCURL" == "x" ]; then
    echo -e "\nDownloading to $(dirname $SOURCE)"
    wget -T 20 -O "$SOURCE" "$SRCURL" 
    if [ $? -ne 0 -o ! -s "$SOURCE" ]; then
      echo "Downloading '$(basename $SOURCE)' failed... aborting the build."
      mv -f "$SOURCE" "$SOURCE".FAIL
## set this for BUILD-TDE.sh to stop on failure
      [[ $EXIT_FAIL == "exit 1" ]] && touch $TMPVARS/download-failure
      ${EXIT_FAIL:-":"}
    fi
  else
    echo "File '$(basename $SOURCE)' not available... aborting the build."
    ${EXIT_FAIL:-":"}
  fi
fi

if [ "$P1" == "--download" ]; then
  echo "Download complete."
  exit 0
fi
} || \
{
## if not creating/updating git, nothing to do in this function for git builds
## otherwise, now not R14.0.? or misc, and we are creating/updating git,
## so [1] start with admin/cmake:
[[ $(cat $TMPVARS/DL_CGIT) == yes ]] && {
cd $BUILD_TDE_ROOT/src/cgit

[[ ! -e $TMPVARS/admin-cmake-done ]] && {
## if admin and cmake exist, update them
[[ -d admin ]] && \
(echo "Updating admin ..."
cd admin
git checkout -- *
git pull)
[[ -d cmake ]] && \
(echo "Updating cmake ..."
cd cmake
git checkout -- *
git pull)

## if admin and cmake don't exist, clone them
[[ ! -d admin ]] && git clone https://mirror.git.trinitydesktop.org/cgit/admin admin
[[ ! -d cmake ]] && git clone https://mirror.git.trinitydesktop.org/cgit/cmake cmake

## place a marker so that admin/cmake update or clone only once per run of BUILD-TDE.sh
touch $TMPVARS/admin-cmake-done
}

## if not tde-i18n
## [2] update or clone PRGNAM

[[ $PRGNAM != tde-i18n ]] && {
## get latest commits if the local repository for PRGNAM exists
[[ -d $PRGNAM ]] && \
(echo "Updating $PRGNAM ..."
cd $PRGNAM
git checkout -- *
git pull)
## if the local repository for PRGNAM doesn't exist, clone it ..
[[ ! -d $PRGNAM ]] && \
git clone https://mirror.git.trinitydesktop.org/cgit/$PRGNAM

## if arts/tdelibs, need libltdl
[[ " arts tdelibs " == *$PRGNAM* ]] && {
[[ -d libltdl ]] && \
(echo "Updating libltdl ..."
cd libltdl
git checkout -- *
git pull)

[[ ! -d libltdl ]] && \
git clone https://mirror.git.trinitydesktop.org/cgit/libltdl
}

## if tdenetwork, need libtdevnc
[[ " tdenetwork " == *$PRGNAM* ]] && {
[[ -d libtdevnc ]] && \
(echo "Updating libtdevnc ..."
cd libtdevnc
git checkout -- *
git pull)

[[ ! -d libtdevnc ]] && \
git clone https://mirror.git.trinitydesktop.org/cgit/libtdevnc
}

true # stop the following i18n download (attempts) if this routine fails and i18n not required
} || \
{
## still creating/updating git
## so [3] for tde-i18n-$lang:

## Use wget to download the required i18n repos to avoid the ~1x10^6 byte download for the full tde-i18n
## - same for both creating and updating
for lang in $I18N
do
cd tdei18n
## remove the previous repo to avoid build failures caused by any unused old files
rm -rf cgit/tde-i18n/plain/tde-i18n-$lang
wget -m --no-parent --no-host-directories https://mirror.git.trinitydesktop.org/cgit/tde-i18n/plain/tde-i18n-$lang/
##will download the tde-i18n-$lang files to:
##$BUILD_TDE_ROOT/src/cgit/tdei18n/cgit/tde-i18n/plain/tde-i18n-$lang/*
cd ..
done
}
}
}

## Installation RPATH:
## Set this to ensure TDE libs have priority when installed
## For tqt3, the configure -R option is used
## Add -Wl,-rpath for gcc/g++ -
## - use --disable-rpath in autotools builds to avoid paths set by configure
## - double quote $SLK[R]CFLAGS with cmake in the SBs for it to recognize the whole string
INST_RPATH="$TQTDIR/lib$LIBDIRSUFFIX"
[[ $TQTDIR != $INSTALL_TDE ]] && INST_RPATH="$INST_RPATH:$INSTALL_TDE/lib$LIBDIRSUFFIX"
SLKCFLAGS="-O2 ${SET_march:-}" # for Misc and libart-lgpl
SLKRCFLAGS="$SLKCFLAGS -Wl,-rpath,'$INST_RPATH'" # for TQt/TDE
[[ $ARCH == x86_64 ]] && \
SLKCFLAGS="$SLKCFLAGS -fPIC" && \
SLKRCFLAGS="$SLKRCFLAGS -fPIC"

# Exit the script on errors:
set -e
trap 'echo "$0 FAILED at line $LINENO" | tee $OUTPUT/error-$PRGNAM.log' ERR
# Catch unitialized variables:
set -u
P1=${1:-1}

# Save old umask and set to 0022:
_UMASK_=$(umask)
umask 0022

[[ $PRE_DOWNLOAD == yes ]] && exit || true # need true to override exit 1 if 'PRE_DOWNLOAD != yes'
}

untar_fn ()
{
cd $TMP_BUILD/tmp-$PRGNAM
##
## [1] firstly test for R14 or misc ..
##
[[ $TDEVERSION == 14.0.? || $TDEMIR_SUBDIR == misc ]] && {
## unpack R14 or misc
echo -e "\n unpacking $(basename $SOURCE) ... \n"
tar -xf $SOURCE
true # if this fails, go to [4] and let SlackBuild fail from there
} || {
##
## [2] not R14 nor misc - is it r14 snapshot?
##
[[ $TDEVERSION == r14.0.? ]] && {
## unpack r14
echo -e "\n unpacking $(basename $SOURCE) ... \n"
tar -xf $SOURCE
## unpack all needed common sources ..
(cd $PRGNAM-$TDEVERSION
echo 'admin
cmake
libltdl
libtdevnc' | while read line
do
[[ -d $line && ! $line == libtdevnc ]] && tar xf $SRCDIR/../../src/$line-$TDEVERSION.$ARCHIVE_TYPE --strip-components=1 -C $line
[[ -d $line && $line == libtdevnc ]] && tar xf $SRCDIR/../../src/$line-r14.0.1.tar.gz --strip-components=1 -C $line
done
true # if this fails, go to [4] and let SlackBuild fail from there
)
}
} || {
##
## [3] not [rR]14 nor misc, so must be cgit ..
## copy git repo but don't copy .git directory:
echo -e "\n copying $PRGNAM source files to build area ... \n"
(cd $BUILD_TDE_ROOT/src/cgit
cp -a --parents $PRGNAM/* $TMP_BUILD/tmp-$PRGNAM/
cp -a --parents {admin,cmake}/* $TMP_BUILD/tmp-$PRGNAM/$PRGNAM/
[[ " arts tdelibs " == *$PRGNAM* ]] && cp -a --parents libltdl/* $TMP_BUILD/tmp-$PRGNAM/$PRGNAM/ || true
[[ " tdenetwork " == *$PRGNAM* ]] && cp -a --parents libtdevnc/* $TMP_BUILD/tmp-$PRGNAM/$PRGNAM/ || true)
} && {
##
## [4] finally, cd into source directory
##
cd $PRGNAM*
}
}

listdocs_fn ()
{
DOCDIR=$PWD # this is set for installdocs_fn
DOCS=$(for file in AUTHORS* rfc4791.pdf ChangeLog* COPYING* CreatingThemes FAQ* HOWTO INSTALL* KNOWNBUGS* LICEN?E* NEWS* *README{$,^[\.*\.txt],/}* ${RM_LIST:-} ${KEYS_LIST:-} TODO* *.lsm ^[README]*.txt PKG-INFO doc/licenses/* doc/FAQ.txt REMARKS ; do [[ -s $file ]] && ls -1 $file;done ) || true
}

chown_fn ()
{
chown -R root:root .
chmod -R u+w,go+r-w,a+rX-st .
}

ltoolupdate_fn ()
{
## edit hard coded tqt directory for tqt3/tqtinterface installed to TQTDIR [!= /usr]
sed -i "s|/usr/include/tqt\"|$TQTDIR/include/tqt\"|" admin/acinclude.m4.in
sed -i "s|/usr/include/tqt3|$TQTDIR/include/tqt|" admin/acinclude.m4.in
## edit hard coded plugins installation directories - could be 'tde'
sed -i "s|trinity|$PLUGIN_INSTALL_DIR|g" admin/acinclude.m4.in

cp /$(grep -h ltmain.sh /var/log/packages/libtool*) admin/
cp /$(grep -h libtool.m4 /var/log/packages/libtool*) admin/libtool.m4.in
cp /$(grep -h missing /var/log/packages/libtool*) admin/

make -f admin/Makefile.common
}

cd_builddir_fn ()
{
mkdir -p build-$PRGNAM
cd build-$PRGNAM
}

make_fn ()
{
make ${NUMJOBS:-} || exit 1
make DESTDIR=$PKG install || exit 1
}

installdocs_fn ()
{
[[ $TDEMIR_SUBDIR == misc || $PRGNAM == libart-lgpl ]] && INSTALL_TDE=/usr
mkdir -p $PKG$INSTALL_TDE/doc/$PRGNAM-$VERSION
(cd ${DOCDIR:-};cp -a --parents ${DOCS:-} $PKG$INSTALL_TDE/doc/$PRGNAM-$VERSION) || true # DOCDIR might not exist
## leave this commented out in case anybody wants to reinstate it
#cat $SRCDIR/$(basename $0) > $PKG$INSTALL_TDE/doc/$PRGNAM-$VERSION/$PRGNAM.SlackBuild
chown -R root:root $PKG$INSTALL_TDE/doc/$PRGNAM-$VERSION
find $PKG$INSTALL_TDE/doc -type f -exec chmod 644 {} \;
}

mangzip_fn ()
{
[[ -d $PKG$INSTALL_TDE/man ]] && {
  find $PKG$INSTALL_TDE/man -type f -name "*.?" -exec gzip -9f {} \;
  for i in $(find $PKG$INSTALL_TDE/man -type l -name "*.?") ; do ln -s $( readlink $i ).gz $i.gz ; rm $i ; done
}
}

strip_fn ()
{
find $PKG | xargs file | grep -e "executable" -e "shared object" | grep ELF \
  | cut -f 1 -d : | xargs strip --strip-unneeded 2> /dev/null || true
}

mkdir_install_fn ()
{
mkdir -p $PKG/install
}

makepkg_fn ()
{
cd $PKG
[[ ! $ARM_FABI ]] || { [[ $ARM_FABI == hard ]] && ARCH=${ARCH}_hf || ARCH=${ARCH}_sf
}
makepkg --linkadd y --chown n $OUTPUT/$PRGNAM-$VERSION-$ARCH-$BUILD.${PKGTYPE:-txz} 
cd $OUTPUT
md5sum $PRGNAM-$VERSION-$ARCH-$BUILD.${PKGTYPE:-txz} > $PRGNAM-$VERSION-$ARCH-$BUILD.${PKGTYPE:-txz}.md5
cat $PKG/install/slack-desc | grep "^$PRGNAM" | grep -v handy > $OUTPUT/$PRGNAM-$VERSION-$ARCH-$BUILD.txt

# Restore the original umask:
umask ${_UMASK_}
}


## paths in doinst.sh should be relative to allow for installation to ROOT != "/"
doinst_sh_fn ()
{
echo "
# Update the desktop database:
/usr/bin/update-desktop-database .$INSTALL_TDE/share/applications

# Update hicolor theme cache:
/usr/bin/gtk-update-icon-cache -f -t .$INSTALL_TDE/share/icons/hicolor

# Update the mime database:
/usr/bin/update-mime-database -Vn usr/share/mime
" >> $PKG/install/doinst.sh
}

libpng16_fn ()
{
(cd /usr/bin
ln -sf libpng16-config libpng-config )
(cd /usr/include
ln -sf libpng16/pngconf.h pngconf.h
ln -sf libpng16/png.h png.h )
(cd /usr/lib$LIBDIRSUFFIX/pkgconfig
ln -sf libpng16.pc libpng.pc )
(cd /usr/lib$LIBDIRSUFFIX
ln -sf libpng16.so libpng.so
ln -sf libpng16.la libpng.la )
}
