#!/bin/sh

## suppress error messages
exec 2>/dev/null

export TMPVARS=/tmp/build/vars
[[ ! -d $TMPVARS ]] && mkdir -p $TMPVARS

## remove marker for git admin/cmake to update or clone only once per run of this script
rm -f $TMPVARS/admin-cmake-done
## remove any PRE_DOWNLOAD record to allow BUILD-TDE.sh to be run in Re-use mode after a pre-download
rm -f $TMPVARS/PRE_DOWNLOAD
## .. and if building 14.0.x/14.1.0, turn off cgit downloads
[[ $(cat $TMPVARS/DL_CGIT) == yes ]] && echo \\Z0\\Zbno > $TMPVARS/DL_CGIT


## don't need this if this script has already been run
## test on $TMPVARS/TDEbuilds, whether or not it has content
[[ -e $TMPVARS/TDEbuilds ]] || {
dialog --cr-wrap --no-shadow --colors --title " Introduction " --msgbox \
"
 Build selected TDE packages and non-TDE dependencies for Slackware 14.2/current.

 Source archives will be downloaded from a geoIP located mirror site and saved to the 'src' directory.

 A package build list is created, and successfully built packages are removed from that list as the build progresses.

 US English is the default language and support for additional languages can be included in the packages.

 The final screen gives a summary of the build setup, with an option to cancel." \
20 75
}


rm -f $TMPVARS/build-new
dialog --cr-wrap --yes-label "Re-use" --no-label "New" --defaultno --no-shadow --colors --title " TDE Build " --yesno \
"
\Zr\Z4\ZbNew\Zn
 Create a new build list.

\Z1R\Zb\Z0e-use\Zn
 Use the existing build list when re-running the build
 * for any SlackBuilds that failed - or
 * after only downloading the sources" \
13 75
[[ $? == 0 ]] && echo no > $TMPVARS/build-new
[[ $? == 1 ]] && rm -f $TMPVARS/TDEbuilds


build_core()
{
# Copyright 2012  Patrick J. Volkerding, Sebeka, Minnesota, USA
# All rights reserved.
#
# Copyright 2014 Willy Sudiarto Raharjo <willysr@slackware-id.org>
# All rights reserved.
#
# Copyright 2015-2017 Thorn Inurcide
# Copyright 2015-2017 tde-slackbuilds project on GitHub
#
# Based on the xfce-build-all.sh script by Patrick J. Volkerding
#
# Redistribution and use of this script, with or without modification, is
# permitted provided that the following conditions are met:
#
# 1. Redistributions of this script must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
#  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
#  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO
#  EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
#  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
#  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
#  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
#  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# These need to be set here:
export INST=${INST:-1}
TMP=${TMP:-/tmp}
export LIBPNG_TMP=$TMP
export BUILD_TDE_ROOT=$(pwd)


###################################################

# set the shell variables needed for the build
#

run_dialog()
{
rm -f $TMPVARS/TDEVERSION
dialog --cr-wrap --nocancel --no-shadow --colors --title " TDE Version " --menu \
"
Set the version of TDE to be built.
 
" \
13 75 3 \
"14.0.9" "the R14.0.9 release - source from archives" \
"14.0.x" "r14.0.10 preview/wip - source from Trinity git" \
"cgit" "R14.1.0 development - source from Trinity git" \
2> $TMPVARS/TDEVERSION


rm -f $TMPVARS/INSTALL_TDE
dialog --cr-wrap --nocancel --no-shadow --colors --title " TDE Installation Directory " --menu \
"
Select the directory that TDE is to be installed in.

Any other option will have to be edited into BUILD-TDE.sh 
 
" \
15 75 3 \
"/opt/tde" "" \
"/opt/trinity" "" \
"/usr" "" \
2> $TMPVARS/INSTALL_TDE


rm -f $TMPVARS/SYS_CNF_DIR
dialog --cr-wrap --nocancel --no-shadow --colors --title " TDE System Configuration " --menu \
"
Select the directory that the TDE System Configuration files
should be installed in.

Selecting '/etc/tde' will also:
* set TDEHOME=~/.tde and TDEROOTHOME=/root/.tde
    \Z0\Zbotherwise defaults to
    TDEHOME=~/.trinity and TDEROOTHOME=/root/.trinity\Zn
* install plugins in $(cat $TMPVARS/INSTALL_TDE)/lib$LIBDIRSUFFIX/tde
    \Z0\Zbotherwise defaults to $(cat $TMPVARS/INSTALL_TDE)/lib$LIBDIRSUFFIX/trinity\Zn
 
" \
20 75 2 \
"/etc/tde" "" \
"/etc/trinity" "" \
2> $TMPVARS/SYS_CNF_DIR


rm -f $TMPVARS/COMPILER
dialog --cr-wrap --nocancel --no-shadow --colors --title " Compiler " --menu \
"
Choose which compiler to use.
 
" \
12 75 2 \
"gcc" "gcc/g++" \
"clang" "clang/clang++" \
2> $TMPVARS/COMPILER


rm -f $TMPVARS/SET_MARCH
rm -f $TMPVARS/ARCH
#
## get the march/mtune options built into gcc to show as an option in the README
GCC_MARCH=$(gcc -Q -O2 --help=target | grep -E "^  -march=|^  -mtune=" | tr -d [:blank:])
#
## what ARCH?
[[ $(getconf LONG_BIT) == 64 ]] && \
echo x86_64 > $TMPVARS/ARCH || \
{ [[ $GCC_MARCH == *armv* ]] && echo arm > $TMPVARS/ARCH
} \
|| echo i586 > $TMPVARS/ARCH
ARCH=$(cat $TMPVARS/ARCH)
#
## if ARCH=arm, add mfpu
[[ $ARCH == arm ]] && GCC_MARCH=$(gcc -Q -O2 --help=target | grep -E "^  -m" | grep -E "arch=|tune=|fpu=" | tr -d [:blank:])
#
## get the native march/mtune options
NATIVE_MARCH=$(echo $(gcc -Q -O2 -march=native --help=target | grep -E "^  -march=|^  -mtune=" | tr -d [:blank:]))
## Slackware 14.2 gcc 5.3.1 fails on this, [*** Error in `gcc': double free or corruption (top): 0x00308b50 ***], so:
NATIVE_MARCH=${NATIVE_MARCH:-"unknown"}
#
## get the default march/mtune options for a 64-bit build from the gcc configuration
[[ $ARCH == x86_64 ]] && DEFAULT_MARCH=$GCC_MARCH
## set the default march etc. options for RPi3 overriding the gcc configuration
[[ $ARCH == arm ]] && DEFAULT_MARCH="-march=armv8-a+crc -mtune=cortex-a53 -mfpu=neon-fp-armv8"
## set the default march/mtune options for i586 and tune for i686 overriding the gcc configuration
[[ $ARCH == i586 ]] && DEFAULT_MARCH="-march=i586 -mtune=i686"
#
## run dialog
EXITVAL=2
until [[ $EXITVAL -lt 2 ]] ; do
dialog --cr-wrap --defaultno --no-shadow --colors --ok-label " 2 / 3 " --cancel-label "1" --help-button --help-label "README" --title " gcc cpu optimization " --inputbox \
"
 The build can be set up for gcc optimization.

 \Zr\Z4\Zb<1>\Zn - the default option \Zb\Z6$(echo $DEFAULT_MARCH)\Zn

 <\Zb\Z02\Zn> - the gcc native option \Zb\Z6$(echo $NATIVE_MARCH)\Zn for this machine

 <\Zb\Z03\Zn> - edit to specify \Zb\Z6march/mtune\Zn for a target machine
\Zb\Z0  [[ use any arrow key x2 to activate the input box for editing ]]\Zn
 
" \
18 75 "$(echo $NATIVE_MARCH)" \
2> $TMPVARS/SET_MARCH && break
EXITVAL=$?
[[ $EXITVAL == 1 ]] && echo $DEFAULT_MARCH > $TMPVARS/SET_MARCH && break
#
## add this to show what mtune option has been overridden
[[ $EXITVAL == 2 ]] && \
{ [[ $ARCH == x86_64 ]] && OPT1_MESSAGE=" * for x86_64 it is \Zb\Z6$(echo $GCC_MARCH)\Zn which is the gcc default."
} || \
{ [[ $ARCH == arm ]] && OPT1_MESSAGE="* for RPi3 [arm] the options are \Zb\Z6-march=armv8-a+crc -mtune=cortex-a53 -mfpu=neon-fp-armv8\Zn overriding the options \Zb\Z6$(echo $GCC_MARCH)\Zn configured into gcc"
} || \
{ [[ $ARCH == i586 ]] && OPT1_MESSAGE=" * for i586 the option has been set at \Zb\Z6-march=i586 -mtune=i686\Zn overriding the option \Zb\Z6$(echo $GCC_MARCH)\Zn configured into gcc"
}
#
dialog --aspect 3 --cr-wrap --no-shadow --colors --scrollbar --ok-label "Return" --msgbox \
"
<\Z2\Zb1\Zn> is the generic default for x86, or is pre-set for RPi3
$OPT1_MESSAGE

<\Z2\Zb2\Zn> is the option identified by gcc as native for this machine.

<\Z2\Zb3\Zn> is to override option <2> to build packages on this machine for installation on another machine with a known cpu-type, allowing that target machine's cpu instruction set to be fully utilized.

The relationship between -march and -mtune options and their use is detailed in the gcc man page in the section 'Intel 386 and AMD x86-64 Options'.
 
" \
0 0
done


rm -f $TMPVARS/NUMJOBS
[[ $ARCH == arm ]] && NUMJOBS="-j8"
dialog --cr-wrap --nocancel --no-shadow --colors --title " Parallel Build " --inputbox \
"
Set the number of simultaneous jobs for make to whatever your system will support.
 
" \
12 75 ${NUMJOBS:-"-j6"} \
2> $TMPVARS/NUMJOBS


rm -f $TMPVARS/I18N
EXITVAL=2
until [[ $EXITVAL -lt 2 ]] ; do
dialog --cr-wrap --nocancel --no-shadow --colors --help-button --help-label "README" --title " Select Additional Languages " --inputbox \
"
 This is the complete list of additional languages supported by TDE.

 A package source may not have support for all these additional languages, but any chosen will be included in the build for that package when its source includes the translation.
 If any other translation is included in the package source, it can be added here but won't be supported by TDE.

 Multiple selections may be made - space separated.

 Build language packages/support for any of:
\Zb\Z6af ar az be bg bn br bs ca cs csb cy da de el en_GB eo es et eu fa fi fr fy ga gl he hi hr hu is it ja kk km ko lt lv mk mn ms nb nds nl nn pa pl pt pt_BR ro ru rw se sk sl sr sr@Latn ss sv ta te tg th tr uk uz uz@cyrillic vi wa zh_CN zh_TW\Zn
 
" \
25 75 \
2> $TMPVARS/I18N && break
[[ $EXITVAL == 2 ]] && dialog --cr-wrap --defaultno --yes-label "Ascii" --no-label "Utf-8" --no-shadow --colors --no-collapse --yesno \
"
The source unpacked is ~950MB, so to save on build space, the SlackBuild script extracts, builds, and removes source for each language package one at a time.

If you can see the two 'y' like characters [che and gamma], then you've probably got a suitable terminal font installed and can choose \Zr\Z4\ZbUtf-8\Zb\Zn to display the language codes, otherwise choose \Z1A\Zb\Z0scii\Zn.

                            <<\Z3\Zb ҷ ɣ \Zn>>

\Zb\Z0A suitable font in a utf8 enabled terminal is needed to display all the extended characters in this list. Liberation Mono in an 'xterm' is known to work. Setting up a 'tty' is not worth the effort.\Zn
" \
19 75
EXVAL=$?
[[ $EXVAL == 1 ]] && dialog --cr-wrap --no-shadow --colors --no-collapse --ok-label "Return" --msgbox \
"
\Zb\Z2PgDn/PgUp to scroll\Zn

$(xzless Core/tde-i18n/langcodes.xz | tr "\n" X | sed 's|X|\\n|g;s|Latn\t|Latn|g')
" \
26 75
[[ $EXVAL == 0 ]] && dialog --cr-wrap --no-shadow --colors --no-collapse --ok-label "Return" --msgbox \
"
\Zb\Z2PgDn/PgUp to scroll\Zn

$(xzless Core/tde-i18n/langcodes.xz |sed 's|\t\+|\t|g'|cut -f 1,3-| tr "\n" X | sed 's|X|\\n|g;s|\t|\t\t|g;s|cyrillic\t|cyrillic|g;s|Latn\t|Latn|g')
" \
26 75
done


rm -f $TMPVARS/EXIT_FAIL
dialog --cr-wrap --defaultno --yes-label "Stop" --no-label "Continue" --no-shadow --colors --title " Action on failure " --yesno \
"
Do you want the build to <\Z1S\Zb\Z0top\Zn> at a failure or \Zr\Z4\ZbContinue\Zn to the next SlackBuild?

Build logs are \Zu$TMP/<program>-*-build-log\ZU,
and configure[cmake] logs will be in
\Zu$TMP/build/tmp-<program>/<program>/build-<program>[/CMakeFiles]\ZU.

A practical build method could be:

 1] build the \Zb\Zr\Z4R\Znequired packages with the <\Z1S\Zb\Z0top\Zn> option.
    This script will then exit on a failure. When the problem has been
    fixed, restart the build with the \Z3\ZbTDE build\Zn|<Re-use> option.

 2] then build other packages with the \Zr\Z4\ZbContinue\Zn option which allows
    this script to continue to the end of the build list whether or
    not any particular SlackBuild has failed.
    \Zr\Z4\ZbContinue\Zn is probably the better choice if only downloading sources.

 3] re-run the build for the remaining programs with the
    \Z3\ZbTDE build\Zn|<Re-use> option and select <Stop> in the confirmation
    screen.
 " \
27 75
[[ $? == 0 ]] && echo "exit 1" > $TMPVARS/EXIT_FAIL
[[ $? == 1 ]] && 2> $TMPVARS/EXIT_FAIL


rm -f $TMPVARS/KEEP_BUILD
dialog --cr-wrap --no-shadow --colors --defaultno --title " Temporary Build Files " --yesno \
"
The default is to remove 'tmp' & 'package' files from a previous package build at the start of building the next package to keep the build area clear.

If following the build method on the previous screen, the answer here should probably be \Zr\Z4\ZbNo\Zn.

Keep \ZuALL\ZU the temporary files, including for successfully built packages?" \
15 75
[[ $? == 0 ]] && echo yes > $TMPVARS/KEEP_BUILD
[[ $? == 1 ]] && echo no > $TMPVARS/KEEP_BUILD


rm -f $TMPVARS/TDEbuilds
dialog --cr-wrap --nocancel --no-shadow --colors --title " TDE Packages Selection " --item-help --checklist \
"
Required builds for a basic working TDE are marked \Zb\Zr\Z4R\Zn.

The packages selected form the build list and so dependencies are listed before the packages that need them. After the \Zb\Zr\Z4R\Znequired packages, the listing is grouped Core/Libs/Apps and then alphabetically within those groups.

Look out for messages in the bottom line of the screen, especially relating to dependencies.

Non-TDE apps are in the Misc category and don't need the \Zb\Zr\Z4R\Znequired TDE packages." \
0 0 0 \
"Deps/tqt3" "\Zb\Zr\Z4R\Zn The Qt package for TDE" off "\Zb\Z6  \Zn" \
"Deps/tqtinterface" "\Zb\Zr\Z4R\Zn TDE bindings to tqt3." off "\Zb\Z6  \Zn" \
"Deps/arts" "\Zb\Zr\Z4R\Zn Sound server for TDE" off "\Zb\Z6   \Zn" \
"Deps/dbus-tqt" "\Zb\Zr\Z4R\Zn A simple IPC library" off "\Zb\Z6   \Zn" \
"Deps/dbus-1-tqt" "\Zb\Zr\Z4R\Zn D-Bus bindings" off "\Zb\Z6   \Zn" \
"Deps/libart-lgpl" "\Zb\Zr\Z4R\Zn The LGPL'd component of libart" off "\Zb\Z6   \Zn" \
"Deps/tqca-tls" "\Zb\Zr\Z4R\Zn Plugin to provide SSL/TLS capability" off "\Zb\Z6   \Zn" \
"Deps/avahi-tqt" "Avahi support" off "\Zb\Z6 Optional for tdelibs and used if installed. Requires Avahi. \Zn" \
"Core/tdelibs" "\Zb\Zr\Z4R\Zn TDE libraries" off "\Zb\Z6 Will build with Avahi support if avahi/avahi-tqt are installed. \Zn" \
"Core/tdebase" "\Zb\Zr\Z4R\Zn TDE base" off "\Zb\Z6   \Zn" \
"Core/tde-i18n" "Additional language support for TDE" off "\Zb\Z6 Required when any \Zb\Z3Additional language support\Zb\Z6 has been selected \Zn" \
"Core/tdeaccessibility" "Accessibility programs" off "\Zb\Z6  \Zn" \
"Core/tdeadmin" "System admin packages" off "\Zb\Z6  \Zn" \
"Core/tdeartwork" "Extra artwork/themes/wallpapers for TDE" off "\Zb\Z6   \Zn" \
"Core/tdeedu" "Educational software" off "\Zb\Z6   \Zn" \
"Core/tdegames" "Games for TDE - atlantik, kasteroids, katomic, etc." off "\Zb\Z6   \Zn" \
" Misc/imlib" "An image loading and rendering library" off "\Zb\Z6 Build-time option for tdegraphics - needed for kuickshow \Zn" \
"Core/tdegraphics" "Misc graphics apps" off "\Zb\Z6   \Zn" \
"Deps/akode" "A player and plugins for aRts music formats" off "\Zb\Z6 For tdemultimedia - aRts-plugin and Juk, and amarok engine \Zn" \
"Core/tdemultimedia" "Multimedia packages for TDE" off "\Zb\Z6 Optional build-time dependency - akode \Zn" \
" Misc/speex" "Audio compression format designed for speech" off "\Zb\Z6 Buildtime option for tdenetwork and amarok. Requires l/speexdsp  \Zn" \
"Core/tdenetwork" "Networking applications for TDE" off "\Zb\Z6 Optional build-time dependency - speex \Zn" \
"Deps/libcaldav" "Calendaring Extensions to WebDAV" off "\Zb\Z6 Optional dependency for korganizer [tdepim] \Zn" \
"Deps/libcarddav" "Online address support" off "\Zb\Z6 Optional dependency for korganizer [tdepim] \Zn" \
"Core/tdepim" "Personal Information Management" off "\Zb\Z6   \Zn" \
"Core/tdeaddons" "Additional plugins and scripts" off "\Zb\Z6 Plugins from tdegames, tdemultimedia, tdepim are build-time options \Zn" \
"Core/tdesdk" "Tools used by TDE developers" off "\Zb\Z6 Requires tdepim \Zn" \
"Core/tdetoys" "TDE Amusements" off "\Zb\Z6   \Zn" \
"Core/tdeutils" "Collection of utilities including ark" off "\Zb\Z6   \Zn" \
"Core/tdevelop" "TDE development programs" off "\Zb\Z6 Requires tdesdk  \Zn" \
" Misc/tidy-html5" "Corrects and cleans up HTML and XML documents" off "\Zb\Z6 Runtime option for Quanta+ [tdewebdev] \Zn" \
"Core/tdewebdev" "Quanta Plus and other applications" off "\Zb\Z6   \Zn" \
"Libs/libkdcraw" "Decode RAW picture files" off "\Zb\Z6 Required for digikam, gwenview and ksquirrel \Zn" \
"Libs/libkexiv2" "Library to manipulate picture metadata" off "\Zb\Z6 Required for digikam, gwenview and ksquirrel. Needs l/exiv2... \Zn" \
"Libs/libkipi" "A common plugin structure" off "\Zb\Z6 Required for digikam, gwenview and ksquirrel \Zn" \
"Libs/kipi-plugins" "Additional functions for digiKam, gwenview and ksquirrel" off "\Zb\Z6 Requires libkdcraw libkexiv2 libkipi. \Zn" \
" Misc/xmedcon" "A medical image conversion utility & library" off "\Zb\Z6 Buildtime option for libksquirrel \Zn" \
"Libs/libksquirrel" "A set of image codecs for KSquirrel" off "\Zb\Z6 Required for ksquirrel. Buildtime options include l/netpbm, t/transfig [fig2dev], Misc/xmedcon \Zn" \
"Apps/abakus" "PC calculator" off "\Zb\Z6 optional dependency l/mpfr which requires l/gmp \Zn" \
" Misc/mp4v2" "Create and modify mp4 files" off "\Zb\Z6 Buildtime option for Amarok  \Zn" \
" Misc/moodbar" "GStreamer plugin for Amarok for moodbar feature" off "\Zb\Z6 Runtime option for Amarok \Zn" \
" Misc/yauap" "A simple commandline audio player" off "\Zb\Z6 Provides an optional engine for Amarok \Zn" \
"Apps/amarok" "A Music Player" off "\Zb\Z6 Optional dependencies - xine-lib, mp4v2, speex, moodbar, akode, yauap \Zn" \
"Apps/digikam" "A digital photo management application + Showfoto viewer" off "\Zb\Z6 Requires kipi-plugins libkdcraw libkexiv2 libkipi.  \Zn" \
"Apps/dolphin" "Dolphin file manager for TDE" off "\Zb\Z6 A d3lphin.desktop file is included - see dolphin.SlackBuild.  \Zn" \
"Apps/filelight" "Graphical diskspace display" off "\Zb\Z6 Runtime requirement x/xdpyinfo \Zn" \
"Apps/gtk-qt-engine" "A GTK+2 theme engine" off "\Zb\Z6   \Zn" \
"Apps/gtk3-tqt-engine" "A GTK+3 theme engine" off "\Zb\Z6   \Zn" \
"Apps/gwenview" "An image viewer" off "\Zb\Z6 Requires kipi-plugins libkdcraw libkexiv2 libkipi.  \Zn" \
"Apps/gwenview-i18n" "Internationalization files for gwenview." off "\Zb\Z6 Provides \Zb\Z3Additional language support\Zb\Z6 for gwenview  \Zn" \
"Apps/k3b" "The CD Creator" off "\Zb\Z6   \Zn" \
"Apps/k3b-i18n" "Internationalization files for k3b." off "\Zb\Z6 Provides \Zb\Z3Additional language support\Zb\Z6 for k3b  \Zn" \
"Apps/k9copy" "A DVD backup utility" off "\Zb\Z6 Requires [tde]k3b and ffmpeg \Zn" \
"Apps/kaffeine" "Media player for TDE" off "\Zb\Z6   \Zn" \
"Apps/kbfx" "Alternate menu for TDE" off "\Zb\Z6   \Zn" \
"Apps/kbookreader" "Twin-panel text files viewer esp. for reading e-books." off "\Zb\Z6   \Zn" \
"Apps/kdbg" "GUI for gdb using TDE" off "\Zb\Z6   \Zn" \
"Apps/kdbusnotification" "A DBUS notification to TDE interface" off "\Zb\Z6   \Zn" \
"Apps/kile" "A TEX and LATEX source editor and shell" off "\Zb\Z6   \Zn" \
"Apps/kkbswitch" "A keyboard layout indicator" off "\Zb\Z6   \Zn" \
"Apps/knemo" "The TDE Network Monitor" off "\Zb\Z6   \Zn" \
"Apps/knetstats" "A network monitor that shows rx/tx LEDs" off "\Zb\Z6   \Zn" \
"Apps/knights" "A graphical chess interface" off "\Zb\Z6   \Zn" \
"Apps/knmap" "A graphical nmap interface" off "\Zb\Z6 Might need tdesudo \Zn" \
" Misc/GraphicsMagick" "Swiss army knife of image processing" off "\Zb\Z6 Buildtime option for chalk[krita] in koffice \Zn" \
"Apps/koffice" "Office Suite" off "\Zb\Z6 Optional build-time dependencies - GraphicsMagick, libpng14  \Zn" \
"Apps/koffice-i18n" "Internationalization files for koffice" off "\Zb\Z6 Provides \Zb\Z3Additional language support\Zb\Z6 for koffice \Zn" \
"Apps/krusader" "File manager for TDE" off "\Zb\Z6   \Zn" \
" Misc/graphviz" "Graph Visualization" off "\Zb\Z6 Runtime option for kscope. pdf/html docs not built by default  \Zn" \
"Apps/kscope" "A source-editing environment for C and C-style languages." off "\Zb\Z6 Runtime options cscope [d/cscope], ctags [ap/vim], dot [graphviz] \Zn" \
"Apps/ksensors" "A graphical interface for sensors" off "\Zb\Z6 Runtime requirement ap/lm_sensors \Zn" \
"Apps/kshutdown" "Shutdown utility for TDE" off "\Zb\Z6   \Zn" \
"Apps/ksquirrel" "An image viewer with OpenGL and KIPI support." off "\Zb\Z6 Requires kipi-plugins libkdcraw libkexiv2 libkipi libksquirrel. \Zn" \
"Apps/ktorrent" "A BitTorrent client for TDE" off "\Zb\Z6   \Zn" \
"Apps/kvkbd" "A virtual keyboard for TDE" off "\Zb\Z6   \Zn" \
"Apps/kvpnc" "TDE frontend for various vpn clients" off "\Zb\Z6 Miscellaneous documentation will be in $(cat $TMPVARS/INSTALL_TDE)/doc/kvpnc-$(cat $TMPVARS/TDEVERSION)  \Zn" \
"Apps/piklab" "IDE for PIC microcontrollers" off "\Zb\Z6   \Zn" \
" Misc/potrace" "For tracing bitmaps to a vector graphics format" off "\Zb\Z6 Required for potracegui, optional for inkscape \Zn" \
"Apps/potracegui" "A GUI for potrace" off "\Zb\Z6 Requires potrace \Zn" \
"Apps/rosegarden" "Audio sequencer and musical notation editor" off "\Zb\Z6 Requires jack-audio-connection-kit liblo and dssi for proper functionality \Zn" \
"Apps/soundkonverter" "Frontend to various audio converters" off "\Zb\Z6   \Zn" \
"Apps/tde-style-lipstik" "Lipstik theme" off "\Zb\Z6   \Zn" \
"Apps/tde-style-qtcurve" "QtCurve theme" off "\Zb\Z6   \Zn" \
"Apps/tdeio-locate" "TDE frontend for the locate command" off "\Zb\Z6   \Zn" \
"Apps/tdepowersave" "Set power consumption and conservation options" off "\Zb\Z6   \Zn" \
"Apps/tdesudo" "Graphical frontend for the sudo command" off "\Zb\Z6   \Zn" \
"Apps/tdmtheme" "TDM theme editor module" off "\Zb\Z6   \Zn" \
"Apps/twin-style-crystal" "Twin theme" off "\Zb\Z6   \Zn" \
"Apps/yakuake" "Quake-style terminal emulator" off "\Zb\Z6   \Zn" \
" Misc/lxml" "Python bindings for libxml2 and libxslt" off "\Zb\Z6 Required to use Inkscape online help \Zn" \
" Misc/inkscape" "SVG editor - an alternative to potrace, potracegui [and GraphicsMagick]." off "\Zb\Z6 Requires lxml if online help facility is required, potrace is a build-time option. \Zn" \
2> $TMPVARS/TDEbuilds
# successful builds are removed from the TDEbuilds list by '$dir ' so add a space to the last entry
# and the " needs to be removed because the Misc entries are double-quoted
sed -i 's|$| |;s|" M|M|g;s|"||g' $TMPVARS/TDEbuilds


## only run this if tqt3 has been selected
rm -f $TMPVARS/TQT_OPTS
rm -f $TMPVARS/PKG_CONFIG_PATH_MOD
[[ $(grep -o tqt3 $TMPVARS/TDEbuilds) ]] && {
dialog --cr-wrap --nocancel --no-shadow --colors --title " TQt options " --item-help --checklist \
"
A minimal packaging of tqt3 will install only the run-time library required for TDE, and the headers and binaries required to build most of TDE.

But tdepim, ksquirrel, tdevelop, and ktorrent need additional libraries.
If you select minimal packaging and intend to build any of those at any time, select keeping their required libs now.

TQt html documentation is ~21M, and can be excluded from the package.

mkspecs is only required for linux-g++
 
" \
25 75 6 \
" minimal" "Minimal packaging" off "\Zb\Z6 Exclude libs and binaries not required for TDE \Zn" \
" pim_ksq" " ├─ Keep lib for tdepim and/or ksquirrel" off "\Zb\Z6 Only required if minimal build selected \Zn" \
" tdevel" " ├─ Keep libs for tdevelop" off "\Zb\Z6 Only required if minimal build selected \Zn" \
" ktorrent" " └─ Keep designer libs for ktorrent" off "\Zb\Z6 Only required if minimal build selected \Zn" \
" nodocs" "Exclude html documentation" on "\Zb\Z6  \Zn" \
" mkspecs" "linux-g++ only" on "\Zb\Z6 Uncheck for the complete set \Zn" \
2> $TMPVARS/TQT_OPTS


PKG_CONFIG_PATH_MOD=$(echo $PKG_CONFIG_PATH| tr : \\n | awk '!seen[$0]++' | tr \\n :|sed 's|:$||')
#
[[ $PKG_CONFIG_PATH != $PKG_CONFIG_PATH_MOD ]] && \
PKGCF_MESSAGE="PKG_CONFIG_PATH is:
\Zb\Z6$PKG_CONFIG_PATH\Zn

This can be set to:
\Zb\Z6$PKG_CONFIG_PATH_MOD\Zn
to remove duplicated paths." || {
PKGCF_MESSAGE="PKG_CONFIG_PATH can be set to remove duplicated paths in its string." && DLG_BOX="14 65"
}
dialog --aspect 3 --cr-wrap --yes-label "Set" --no-label "Leave" --defaultno --no-shadow --colors --title " Setting PKG_CONFIG_PATH " --yesno \
"
$PKGCF_MESSAGE

This will be done with doinst.sh -> pkgconfig.sh and it will therefore apply whenever this build of tqt3 is installed.

Either way, the TDE and TQT pkgconfig paths will be added if not already included.

" \
${DLG_BOX:-0 0}
[[ $? == 0 ]] && echo set > $TMPVARS/PKG_CONFIG_PATH_MOD
[[ $? == 1 ]] && echo leave >  $TMPVARS/PKG_CONFIG_PATH_MOD
}


## only run this if tdelibs has been selected
rm -f $TMPVARS/SPELL
[[ $(grep -o tdelibs $TMPVARS/TDEbuilds) ]] && {
dialog --cr-wrap --nocancel --no-shadow --colors --title " Spell checker " --menu \
"
Choose a Spell checker.
If you chose a spell checker it must be installed, or the build will exit.

This won't affect any Spell checker being installed later, it's just a work-around for a mandatory selection being forced in the source.
 
" \
19 75 4 \
" Aspell" "" \
" Hspell" "" \
" Ispell" "" \
" None" "Don't have one installed" \
2> $TMPVARS/SPELL
}


## only run this if tdebase has been selected
rm -f $TMPVARS/RUNLEVEL
[[ $(grep -o tdebase $TMPVARS/TDEbuilds) ]] && {
EXITVAL=2
until [[ $EXITVAL -lt 2 ]] ; do
dialog --cr-wrap --no-shadow --yes-label "4" --no-label "3" --help-button --help-label "README" --colors --defaultno --title " TDM " --yesno \
"
TDM is included in the tdebase build.

Select:
runlevel \Zb\Z64\Zn - to login with TDM and boot into the GUI
runlevel \Zb\Z63\Zn - to boot into a terminal - the Slackware default.

This option can be overridden later by editing /etc/inittab.
" \
13 75
EXITVAL=$?
[[ $EXITVAL == 0 ]] && echo 4 > $TMPVARS/RUNLEVEL
[[ $EXITVAL == 1 ]] && echo 3 > $TMPVARS/RUNLEVEL
[[ $EXITVAL == 2 ]] && dialog --cr-wrap --no-shadow --colors --ok-label "Return" --msgbox \
"
$(cat Core/tdebase/README|sed "s|/{TDE_installation_dir}|$(cat $TMPVARS/INSTALL_TDE)|;s|(|\\\Z6\\\Zb|;s|)|\\\Zn|")
" \
30 75
done
}


## only run this if building koffice has been selected
[[ $(sed 's|koffice-||' $TMPVARS/TDEbuilds | grep -o Apps/koffice) ]] && \
{
rm -f $TMPVARS/Krita_OPTS
dialog --cr-wrap --nocancel --no-shadow --colors --title " Building chalk in koffice " --item-help --checklist \
"
There are three options that can be set up for building the imaging app in koffice.

[1] It is called \Zb\Z3chalk\Zn in TDE but is known as \Zb\Z3krita\Zn most other places.

[2] .pngs loaded into chalk/krita will crash if it is built with libpng-1.6, but will load if libpng-1.4 is used for the build.
  If libpng is chosen here, it will be added to the build list and the package placed in $TMP - not installed. It will then be installed by koffice.SB if the libpng unversioned headers and libs are not linked to libpng14.
  The koffice.SB will restore those links to libpng16 when the build has finished or failed.

[3] GraphicsMagick will enable an extended range of image formats to be loaded and saved. ImageMagick should be an alternative, but building fails with that, so without GM, the range of supported image formats will be limited.
  If GM is chosen here, it will be added to the build list if not already selected or installed." \
30 75 3 \
" krita" "Set the app name to krita" on "\Zb\Z6 otherwise will be \Zb\Z3chalk\Zn" \
" libpng14" "Build with libpng-1.4" on "\Zb\Z6 otherwise will be \Zb\Z3libpng-1.6\Zn" \
" useGM" "Use GraphicsMagick" on "\Zb\Z6  \Zn" \
2> $TMPVARS/Krita_OPTS
## If GM has been selected and isn't in the build list or installed, add it to the build list before koffice
GM_VERSION=$(grep VERSION:- $BUILD_TDE_ROOT/Misc/GraphicsMagick/GraphicsMagick.SlackBuild|cut -d- -f2|cut -d} -f1)
[[ $(cat $TMPVARS/Krita_OPTS) == *useGM* ]] && \
[[ $(cat $TMPVARS/TDEbuilds) != *GraphicsMagick* ]] && \
[[ ! $(ls /var/log/packages/GraphicsMagick-$GM_VERSION*) ]] && \
sed -i 's|Apps/koffice|Misc/GraphicsMagick &|' $TMPVARS/TDEbuilds
## If libpng-1.4 has been selected and hasn't already been built, add it to the build list before koffice
PNG_VERSION=$(grep VERSION:- $BUILD_TDE_ROOT/Misc/libpng/libpng.SlackBuild|cut -d- -f2|cut -d} -f1)
[[ $(cat $TMPVARS/Krita_OPTS) == *libpng14* ]] && \
[[ ! $(ls $LIBPNG_TMP/libpng-$PNG_VERSION-*-1.txz) ]] && \
sed -i 's|Apps/koffice|Misc/libpng &|' $TMPVARS/TDEbuilds
}


## only run this if kvkbd has been selected
rm -f $TMPVARS/WinLock
rm -f $TMPVARS/kvkbd-bg
rm -f $TMPVARS/kvkbd-keycolr
[[ $(grep -o kvkbd $TMPVARS/TDEbuilds) ]] && {
dialog --cr-wrap --no-shadow --yes-label "No Lock" --no-label "Lock" --colors --defaultno --title " Kvkbd Win Keys " --yesno \
"
The \Zb\Z6LWin\Zn and \Zb\Z6RWin\Zn keys on the \Zb\Z6Kvkbd\Zn keyboard are set to 'lock' for the next key click.

If they're to be used as control keys to map a number of characters or functions, then they need to be set to \Zr\Z4\ZbLock\Zn while the next key is clicked - this is to simulate holding down the key on a physical keyboard.

If they will only be used as alternatively mapped keys using xmodmap, then they will need to be set to generate a keycode on a single click - \Z1N\Zb\Z0o Lock\Zn.
" \
17 75
[[ $? == 0 ]] && 2> $TMPVARS/WinLock
[[ $? == 1 ]] && echo 1 > $TMPVARS/WinLock

dialog --cr-wrap --no-collapse --nocancel --no-shadow --colors --title " Kvkbd background colour " --inputbox \
"
The default background colour for the keyboard is black.

To change it, enter the colour you want in any of these forms, including the double quotes where shown.
These examples are all the same colour:

Named: \Zb\Z6\"antiquewhite3\"\Zn
Hex:      \Zb\Z6\"#cdc0b0\"\Zn
RGB:    \Zb\Z6 205,192,176\Zn
 
" \
19 75 "\"black\"" \
2> $TMPVARS/kvkbd-bg

dialog --cr-wrap --no-collapse --nocancel --no-shadow --colors --title " Kvkbd keys/buttons colour " --inputbox \
"
The default colour for the keys and buttons is the system button colour.

To change it, enter the colour you want in any of these forms, including the double quotes where shown.
These examples are all the same colour:

Named:   \Zb\Z6\"gray94\"\Zn
Hex:    \Zb\Z6\"#f0f0f0\"\Zn
RGB:  \Zb\Z6 240,240,240\Zn

Choosing a colour for the keys doesn't work for styles like plastik and keramik which have an outline within the 30x30 key background footprint, but is OK for cde and others.
 
" \
24 75 \
2> $TMPVARS/kvkbd-keycolr
}


## option to prefix some package names
## get a list of packages that have SlackBuilds set up to use the prefix 'tde'
grep TDEPFX [ACDL]???/*/*SlackBuild | grep PKGNAM | cut -d/ -f2 > $TMPVARS/TDEPFX_packages
## then create a list of those being built
FILE=""
for file in $(cat $TMPVARS/TDEPFX_packages)
do
[[ $(cat $TMPVARS/TDEbuilds) == *"$file "* ]] && FILE="$FILE $file"
done
## and then if there is anything in that list, run this dialog
rm -f $TMPVARS/TDEPFX
[[ $FILE ]] && {
dialog --aspect 7 --cr-wrap --yes-label "tde" --no-label "None" --defaultno --no-shadow --colors --title " tde prefix " --yesno \
"
A 'tde' prefix can be added to some package names
[\Zb\Z6$FILE\Zn ]
to avoid confusion with identical packages which might be installed for KDE.

" \
0 0
[[ $? == 0 ]] && echo tde > $TMPVARS/TDEPFX
[[ $? == 1 ]] && touch $TMPVARS/TDEPFX
}


## this dialog will only run if any of the selected packages has a README
rm -f $TMPVARS/READMEs
## generate list of READMEs ..
RM_LIST=$(find [ACDLM][a-z]* -name "README" | grep -v tdebase)
for package in $(cat $TMPVARS/TDEbuilds)
do
[[ $RM_LIST == *$package* ]] && {
echo "\Zb\Z6\Zu$package\ZU\Zn

$(cat $package/README)
" >> $TMPVARS/READMEs
}
done
## .. if there is a list, run dialog
[[ $(cat $TMPVARS/READMEs) ]] && {
dialog --cr-wrap --defaultno --no-shadow --colors --title " READMEs " --yesno \
"
Some of the selected packages have READMEs in their SlackBuilds directories.

Do you want to read them?
 " \
10 75
[[ $? == 0 ]] && dialog --no-collapse --cr-wrap --no-shadow --colors --ok-label "Close" --msgbox \
"
$(cat $TMPVARS/READMEs)" \
30 75
}


rm -f $TMPVARS/DL_CGIT  # place this here to facilitate testing for summary screen
[[ $(cat $TMPVARS/TDEVERSION) == cgit || $(cat $TMPVARS/TDEVERSION) == 14.0.x ]] && \
[[ $(grep -o [ACDLM][a-z]*/ $TMPVARS/TDEbuilds | sort | head -n1) != Misc/ ]] && {
dialog --cr-wrap --no-shadow --colors --defaultno --title " TDE development build " --yesno \
"
Create and/or update the git repositories local copies.

\Z1Y\Zb\Z0es\Zn
 * For a first run - will clone the git repositories
 * For subsequent runs - will update only
 * If the current build list includes new apps, and you don't want the
   existing repos updated, the new apps should be run as a new group
   initially as selective updating is not supported
 * Local repositories will be created/updated as each package is built
   OR can be downloaded before the build -> see next screen

\Zr\Z4\ZbNo\Zn
 * The build will use sources already downloaded
 
" \
19 75
[[ $? == 0 ]] && echo yes > $TMPVARS/DL_CGIT
[[ $? == 1 ]] && echo no > $TMPVARS/DL_CGIT
}


#rm -f $TMPVARS/PRE_DOWNLOAD  ## this is done at the head of this script
[[ $(cat $TMPVARS/TDEVERSION) == 14.0.9 ]] && PRE_DOWNLOAD_MESSAGE="Only the source archives not already in 'src' will be downloaded."
[[ $(cat $TMPVARS/TDEVERSION) == cgit || $(cat $TMPVARS/TDEVERSION) == 14.0.x ]] && PRE_DOWNLOAD_MESSAGE="All cgit sources for the build list packages will be cloned/updated.\nMisc archives will only be downloaded if not already in 'src'." && LINES=18
## testing for cgit!=no will allow =yes or null, which is the 14.0.9 build case
[[ $(cat $TMPVARS/DL_CGIT) != no ]] &&  {
dialog --cr-wrap --no-shadow --colors --defaultno --title " Only download sources " --yesno \
"
This would be useful for running the build off-line.

\Z1Y\Zb\Z0es\Zn
 Download the sources for the build list without building packages.
 The build list will be retained, and BUILD-TDE.sh will need to be
 re-run selecting the \Z3\ZbTDE build\Zn|<Re-use> option to build the packages.

\Zr\Z4\ZbNo\Zn
 Download sources as each package is built.

$PRE_DOWNLOAD_MESSAGE
 
" \
${LINES:-17} 75
[[ $? == 0 ]] && echo yes > $TMPVARS/PRE_DOWNLOAD
[[ $? == 1 ]] && echo no > $TMPVARS/PRE_DOWNLOAD
}

}

# Is this a 32 or 64 bit system?
# 'uname -m' won't identify a 32 bit system with a 64 bit kernel
[[ $(getconf LONG_BIT) == 64 ]] && LIBDIRSUFFIX="64" || LIBDIRSUFFIX=""

[[ ! -e $TMPVARS/TDEbuilds ]] && run_dialog

# option to change to stop the build when it fails
if [[ $(cat $TMPVARS/build-new) == no ]] ; then
if [[ $(cat $TMPVARS/EXIT_FAIL) == "" ]] ; then

dialog --cr-wrap --defaultno --yes-label "Stop" --no-label "Continue" --no-shadow --colors --title " Confirm action on failure " --yesno \
"
If there is a failure, this script is set up to continue to the next SlackBuild in the re-used build list.

Do you still want it to do that or change to <\Z1S\Zb\Z0top\Zn> ?
 " \
10 60
[[ $? == 0 ]] && echo "exit 1" > $TMPVARS/EXIT_FAIL

fi
fi


######################
# there should be no need to make any changes below

export TDEVERSION=$(cat $TMPVARS/TDEVERSION)
export INSTALL_TDE=$(cat $TMPVARS/INSTALL_TDE)
export SYS_CNF_DIR=$(cat $TMPVARS/SYS_CNF_DIR)
export COMPILER=$(cat $TMPVARS/COMPILER)
[[ $COMPILER == gcc ]] && export COMPILER_CXX="g++" || export COMPILER_CXX="clang++"
export SET_march=$(cat $TMPVARS/SET_MARCH)
export ARCH=$(cat $TMPVARS/ARCH)	# set again for the 'continue' option
export TDE_MIRROR=${TDE_MIRROR:-https://mirror.ppa.trinitydesktop.org/trinity}
export NUMJOBS=$(cat $TMPVARS/NUMJOBS)
export I18N=$(cat $TMPVARS/I18N)
export LINGUAS=$I18N
export TQT_OPTS=$(cat $TMPVARS/TQT_OPTS)
export EXIT_FAIL=$(cat $TMPVARS/EXIT_FAIL)
export KEEP_BUILD=$(cat $TMPVARS/KEEP_BUILD)
export RUNLEVEL=$(cat $TMPVARS/RUNLEVEL)
export PRE_DOWNLOAD=$(cat $TMPVARS/PRE_DOWNLOAD)
export TDEPFX=$(cat $TMPVARS/TDEPFX)
export WinLock=$(cat $TMPVARS/WinLock)

## Set installation directory for tqt
TQTDIR=$INSTALL_TDE

PKG_CONFIG_PATH=$INSTALL_TDE/lib$LIBDIRSUFFIX/pkgconfig:${PKG_CONFIG_PATH:-}
[[ $TQTDIR != $INSTALL_TDE ]] && PKG_CONFIG_PATH=$TQTDIR/lib$LIBDIRSUFFIX/pkgconfig:$PKG_CONFIG_PATH

PATH=$INSTALL_TDE/bin:$PATH
[[ $TQTDIR != $INSTALL_TDE ]] && PATH=$TQTDIR/bin:$PATH

export LIBDIRSUFFIX
export TQTDIR
export PKG_CONFIG_PATH
export PATH
## to provide an ARCH suffix for the package name - see makepkg_fn in get-source.sh
export ARM_FABI=$(readelf -Ah $(which bash)|grep -oE "soft|hard")
## override hard coded trinity plugins directory - used for:
## autotools: get-source.sh|ltoolupdate_fn
## cmake: -DPLUGIN_INSTALL_DIR=
export PLUGIN_INSTALL_DIR=$(cat $TMPVARS/SYS_CNF_DIR | cut -d/ -f3)

### set up variables for the summary list:
## New build
[[ $(cat $TMPVARS/build-new) != no ]] && NEW_BUILD=yes || NEW_BUILD='no - re-using existing'
#
## Action on failure
[[ $EXIT_FAIL == "exit 1" ]] && AOF=stop
#
## if tdebase selected
[[ $(grep -o tdebase $TMPVARS/TDEbuilds) ]] && TDMRL=$RUNLEVEL
#
## koffice - only if it is being built
[[ $(grep -o "Apps/koffice " $TMPVARS/TDEbuilds) ]] && {
[[ $(cat $TMPVARS/Krita_OPTS) == *krita* ]] && RVT=yes || RVT=no
[[ $(cat $TMPVARS/Krita_OPTS) == *libpng14* ]] && USE_PNG=yes || USE_PNG=no
[[ $(cat $TMPVARS/Krita_OPTS) == *useGM* ]] && USE_GM=yes || USE_GM=no
} && \
KOFFICE="
koffice:
 revert chalk to krita                  \Zb\Z6$RVT\Zn
 build with libpng14                    \Zb\Z6$USE_PNG\Zn
 build with GraphicsMagick              \Zb\Z6$USE_GM\Zn"
#
## tqt3 options, if tqt3 is being built
[[ $(grep -o tqt3 $TMPVARS/TDEbuilds) ]] && {
TQT_BLD=yes && [[ $TQT_OPTS != *minimal* ]] && TQT_BLD=no
TQT_DOCS=no && [[ $TQT_OPTS != *nodocs* ]] && TQT_DOCS=yes
}
#
## whether cloning or updating cgit
CLONE=$(cat $TMPVARS/DL_CGIT)
#
## whether installing packages as they are built
INST_PACKAGE=yes && [[ $INST == 0 ]] && INST_PACKAGE=no
#
## emphasise downloading only, not building
[[ $PRE_DOWNLOAD == yes ]] && DL_BLD_MSG="Download sources"
#
## whether using tde prefix
[[ -e $TMPVARS/TDEPFX ]] && tde_prefix=\\Zn\\Zb\\Z2tde\\Zn && [[ ! -s $TMPVARS/TDEPFX ]] && tde_prefix=no
#
## start dialog
EXITVAL=2
until [[ $EXITVAL -lt 2 ]] ; do
dialog --aspect 3 --no-collapse --cr-wrap --yes-label "${DL_BLD_MSG:-Start}" --no-label "Cancel" --help-button --help-label "Build List" --no-shadow --defaultno --colors --title " ${DL_BLD_MSG:-Start TDE Build} " --yesno \
"
Setup is complete - these are the build options:

New build list                          \Zb\Z6$NEW_BUILD\Zn
TDE version                             \Zb\Z6$TDEVERSION\Zn
Clone/update cgit local repositories    \Zb\Z6${CLONE:-\Z0\Zbn/a}\Zn
Only download sources                   \Zb\Z6${PRE_DOWNLOAD:-\Z0\Zbn/a}\Zn
TDE installation directory              \Zb\Z6$INSTALL_TDE\Zn
TDE system configuration directory      \Zb\Z6$SYS_CNF_DIR\Zn
Compiler                                \Zb\Z6$COMPILER\Zn
gcc cpu optimization                    \Zb\Z6$SET_march\Zn
Number of parallel jobs                 \Zb\Z6$(echo $NUMJOBS|sed 's|-j||')\Zn
Additional languages                    \Zb\Z6${I18N:-none}\Zn
Minimal tqt build                       \Zb\Z6${TQT_BLD:-\Z0\Zbn/a}\Zn
Include tqt html docs                   \Zb\Z6${TQT_DOCS:-\Z0\Zbn/a}\Zn
Action on failure                       \Zb\Z6${AOF:-continue}\Zn
Keep the temporary build files          \Zb\Z6$KEEP_BUILD\Zn
Runlevel for TDM                        \Zb\Z6${TDMRL:-\Z0\Zbn/a}\Zn${KOFFICE:-}\Zn
Install packages as they are built      \Zb\Z6$INST_PACKAGE\Zn
Prefix for packages common to KDE       \Zb\Z6${tde_prefix:-\Z0\Zbn/a}\Zn
 
" \
0 0
EXITVAL=$?
[[ $EXITVAL == 2 ]] && dialog --aspect 5 --cr-wrap --no-shadow --colors --scrollbar --ok-label "Return" --msgbox \
"
The packages to be built are -
\Z0\Zb[sorted list, see
$TMPVARS/TDEbuilds
for the build order]\Zn

$(cat $TMPVARS/TDEbuilds | tr -s " " "\n"|sed 's|^|\\Z0\\Zb|;s|/|\\Zn  |'|sort -k 2)

" \
0 0
[[ $EXITVAL == 0 ]] && break
[[ $EXITVAL == 1 ]] && echo -e "\n\nBuild Cancelled\n" && exit 1
echo
done

######################################################
# package(s) build starts here
## If there is a download failure in getsource_fn, it needs to be communicated to this script if the build is set to stop on failure
## getsource_fn is a function in get-source.sh which is a child of the SlackBuild script which is a child of this script and that failure needs to be carried back here
## $TMPVARS/download-failure will be created if needed for that purpose, so remove any possible previous file
rm -f $TMPVARS/download-failure

# Loop for all packages
for dir in $(cat $TMPVARS/TDEbuilds)
do
[[ ! -e $TMPVARS/download-failure ]] && {
   { [[ $dir == Deps* ]] && export TDEMIR_SUBDIR="/dependencies"; } \
|| { [[ $dir == Core* ]] && export TDEMIR_SUBDIR=""; } \
|| { [[ $dir == Libs* ]] && export TDEMIR_SUBDIR="/libraries"; } \
|| { [[ $dir == Apps* ]] && export TDEMIR_SUBDIR="/applications"; } \
|| { [[ $dir == *Misc* ]] && export TDEMIR_SUBDIR="misc"; } # used for untar_fn - leading slash deliberately omitted

  # Get the package name
  package=$(echo $dir | cut -f2- -d /)

  # Change to package directory
  cd $BUILD_TDE_ROOT/$dir || ${EXIT_FAIL:-"true"}

  # Get the version
  version=$(grep "VERSION=" $package.SlackBuild | head -n1 | cut -d "=" -f2)

  # Get the build
  build=${BUILD:-$(grep "BUILD:" $package.SlackBuild | cut -d "-" -f2 | sed 's|}||')}

  # The real build starts here
  echo -e "\033[39;1m

 Starting $package.SlackBuild
 $(printf '%0.s\"' $(seq 1 $[${#package}+20]))
  \033[0m"
## set 'noarch' for i18n packages
  ARCH_i18n="" && [[ $package == *i18n* ]] && ARCH_i18n=noarch
## TDEPFX could be set '' from null [n/a], in which case set TDE_PFX="", or
## if building one of these packages, can be set [tde] or '' [None=no]
  TDE_PFX="" && [[ $(cat $TMPVARS/TDEPFX_packages) == *$package* ]] && TDE_PFX=$TDEPFX
## set up separate log for source downloads
  LOG="" && [[ $PRE_DOWNLOAD == yes ]] && LOG="source_download"
  script -c "sh $package.SlackBuild" $TMP/$TDE_PFX$package-$(eval echo $version)-${LOG:-"${ARCH_i18n:-$ARCH}-$build-build"}-log || ${EXIT_FAIL:-"true"}

# remove colorizing escape sequences from build-log
# Re: http://serverfault.com/questions/71285/in-centos-4-4-how-can-i-strip-escape-sequences-from-a-text-file
  sed -ri "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" $TMP/$TDE_PFX$package-$(eval echo $version)-${LOG:-"${ARCH_i18n:-$ARCH}-$build-build"}-log || ${EXIT_FAIL:-"true"}

checkmakepkg ()
{
## test whether the Slackware package has been built .. 
[[ $(ls $TMP/$TDE_PFX$package-$(eval echo $version)-*-$build*.txz) ]] && \
sed -i "s|$dir ||" $TMPVARS/TDEbuilds || {
## if unsuccessful, display error message \
echo "
      Error:  $TDE_PFX$package package ${LOG:-build} failed
      Check the ${LOG:-build} log $TMP/$TDE_PFX$package-$(eval echo $version)-${LOG:-"${ARCH_i18n:-$ARCH}-$build-build"}-log
      "
## if koffice was building with libpng14, restore the libpng16 headers for any following builds
[[ $(cat $TMPVARS/Krita_OPTS) == *libpng14* ]] && source $BUILD_TDE_ROOT/get-source.sh && libpng16_fn || true
${EXIT_FAIL:-":"}
}
}

## skip build/packaging check if only downloading sources
[[ $PRE_DOWNLOAD == yes ]] || {
## install packages
[[ $INST == 1 ]] && [[ $package != tde-i18n ]] && [[ $package != libpng ]] && upgradepkg --install-new --reinstall $TMP/$TDE_PFX$package-$(eval echo $version)-*-$build*.txz && \
checkmakepkg || ${EXIT_FAIL:-"true"}
## tde-i18n package installation is handled in tde-i18n.SlackBuild because if more than one i18n package is being built, only the last one will be installed by upgradepkg here - test for last language in the I18N list to ensure they've all been built
[[ $package == tde-i18n ]] && package=$package-$(cat $TMPVARS/LASTLANG) && \
checkmakepkg
## create libpng-1.4 package only - it will be installed by the koffice.SB because it overrides libpng headers which for Sl14.2/current point to libpng16.
## if building only, and/or libpng, just check that the package has been created
[[ $INST == 0 ]] || [[ $package == libpng ]] && \
checkmakepkg
}

  # back to original directory
  cd $BUILD_TDE_ROOT
}
done
}

build_core || ${EXIT_FAIL:-"true"}

