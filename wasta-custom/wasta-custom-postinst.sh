#!/bin/bash

# ==============================================================================
# wasta-custom-postinst.sh
#
#   This script is automatically run by the postinst configure step on
#       installation of wasta-custom.  It can be manually re-run, but is
#       only intended to be run at package installation.
#
#   2013-12-03 rik: initial script
#   2017-12-27 jcl: rework - change LO extension to bundle method, not shared
#   2018-05-02 rik: initial wasta-custom-moz script
#   2019-03-29 rik: updates to wasta-custom-moz
#
# ==============================================================================

# ------------------------------------------------------------------------------
# Check to ensure running as root
# ------------------------------------------------------------------------------
#   No fancy "double click" here because normal user should never need to run
if [ $(id -u) -ne 0 ]
then
  echo
  echo "You must run this script with sudo." >&2
  echo "Exiting...."
  sleep 5s
  exit 1
fi

# ------------------------------------------------------------------------------
# Initial Setup
# ------------------------------------------------------------------------------

BRANCH_ID=moz
RESOURCE_DIR=/usr/share/wasta-custom-${BRANCH_ID}/resources
DEBUG=""  #set to yes to enable testing helps

# ------------------------------------------------------------------------------
# Adjust Software Sources
# ------------------------------------------------------------------------------

# get series, load them up.
SERIES=$(lsb_release -sc)
case "$SERIES" in

  trusty|qiana|rebecca|rafaela|rosa)
    #LTS 14.04-based Mint 17.x
    REPO_SERIES="trusty"
  ;;

  xenial|sarah|serena|sonya|sylvia)
    #LTS 16.04-based Mint 18.x
    REPO_SERIES="xenial"
  ;;

  bionic|tara)
    #LTS 18.04-based Mint 19.x
    REPO_SERIES="bionic"
  ;;

  *)
    # Don't know the series, just go with what is reported
    REPO_SERIES=$SERIES
  ;;
esac

echo
echo "*** Beginning wasta-custom-${BRANCH_ID}-postinst.sh for ${REPO_SERIES}"
echo

APT_SOURCES_D=/etc/apt/sources.list.d
if [ -x /usr/bin/wasta-offline ] &&  [[ $(pgrep -c wasta-offline) > 0 ]];
then
  if [ -e /etc/apt/sources.list.d.wasta ];
  then
    echo "*** wasta-offline 'offline only' mode detected"
    echo
    APT_SOURCES_D=/etc/apt/sources.list.d.wasta
  else
    echo "*** wasta-offline 'offline and internet' mode detected"
    echo
  fi
fi

# ------------------------------------------------------------------------------
# Disable software update checking / reduce bandwidth for apt
# ------------------------------------------------------------------------------
# Automatically check for updates: daily(1), week(7), two weeks(14), never(0)
#if [ -e /etc/apt/apt.conf.d/10periodic ]; then
#  sed -i -e '/APT::Periodic::Update-Package-Lists/ s|\".*\"|\"0\"|' \
#      /etc/apt/apt.conf.d/10periodic
#fi
#if [ -e /etc/apt/apt.conf.d/20auto-upgrades ]; then
#  sed -i -e '/APT::Periodic::Update-Package-Lists/ s|\".*\"|\"0\"|' \
#         -e '/APT::Periodic::Unattended-Upgrade/   s|\".*\"|\"0\"|' \
#      /etc/apt/apt.conf.d/20auto-upgrades
#fi

# Notify me of a new Ubuntu version: never, normal, lts
if [ -e /etc/update-manager/release-upgrades ]; then
  sed -i -e 's|^Prompt=.*|Prompt=never|' /etc/update-manager/release-upgrades
fi

if ! [ -e /etc/apt/apt.conf.d/99translations ]; then
  cat << EOF >  /etc/apt/apt.conf.d/99translations
Acquire::Languages \"none\";
EOF
fi

# ------------------------------------------------------------------------------
# LibreOffice PPA management
# ------------------------------------------------------------------------------
LO_61=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-1-*)
if ! [ -e "${LO_61[0]}" ] \
&& ! [ "${REPO_SERIES}" == "precise" ]; then
  echo "LibreOffice 6.1 PPA not found. Adding it..."

  #key already added by wasta, so no need to use the internet with add-apt-repository
  #add-apt-repository --yes ppa:libreoffice/libreoffice-6-1
  cat << EOF >  $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-6-1-$REPO_SERIES.list
deb http://ppa.launchpad.net/libreoffice/libreoffice-6-1/ubuntu $REPO_SERIES main
# deb-src http://ppa.launchpad.net/libreoffice/libreoffice-6-1/ubuntu $REPO_SERIES main
EOF
fi

LO_60=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-0-*)
LO_61=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-1-*)
if [ -e "${LO_61[0]}" ]; then
  if [ -e "${LO_60[0]}" ]; then
    echo "   LO 6.0 PPA found - removing it."
    rm "${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-0-"*
  fi
fi

LO_5X=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-5-*)
LO_6X=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-*)
if [ -e "${LO_6X[0]}" ]; then
  if [ -e "${LO_5X[0]}" ]; then
    echo "   LO 5.x PPA found - removing it."
    rm "${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-5-"*
  fi
fi

# ------------------------------------------------------------------------------
# Schema overrides - set customized defaults for gnome software
# !! Not removed if wasta-custom-${BRANCH_ID} is uninstalled !!
# ------------------------------------------------------------------------------
SCHEMA_DIR=/usr/share/glib-2.0/schemas

echo && echo "*** Compile changed gschema default preferences"
[ "$DEBUG"] && glib-compile-schemas --strict ${SCHEMA_DIR}/
glib-compile-schemas ${SCHEMA_DIR}/

# ------------------------------------------------------------------------------
# Install fonts
# !! Not removed if wasta-custom-${BRANCH_ID} is uninstalled !!
# ------------------------------------------------------------------------------
REBUILD_CACHE=NO
TTF=(${RESOURCE_DIR}/*.ttf)
if [ -e "${TTF[0]}" ]; then
  echo && echo "installing extra fonts..."
  mkdir -p "/usr/share/fonts/truetype/${BRANCH_ID}"
  cp "${RESOURCE_DIR}/"*.ttf "/usr/share/fonts/truetype/${BRANCH_ID}"
  chmod -R +r "/usr/share/fonts/truetype/${BRANCH_ID}"
  REBUILD_CACHE=YES
else
  [ "$DEBUG"] && echo "DEBUG: no fonts to install"
fi

if [ "$REBUILD_CACHE" == "YES" ]; then
  fc-cache -fs
fi

# ------------------------------------------------------------------------------
# Per User Adjustments
# ------------------------------------------------------------------------------
LOCAL_USERS=""
for USER_FOLDER in $(ls -1 home)
do
    # if user is in /etc/passwd then it is a 'real user' as opposed to
    # something like wasta-remastersys
    if [ "$(grep $USER_FOLDER /etc/passwd)" ];
    then
        LOCAL_USERS+="$USER_FOLDER "
    fi
done

for CURRENT_USER in $LOCAL_USERS;
do
    # put per-user commands below, using following syntax:
    #    su -l "$CURRENT_USER" -c "command to execute"
done

# ------------------------------------------------------------------------------
# Set system-wide Paper Size
# ------------------------------------------------------------------------------
# Note: This sets /etc/papersize.  However, many apps do not look at this
#   location, but instead maintain their own settings for paper size :-(
paperconfig -p a4

# ------------------------------------------------------------------------------
# Change system-wide locale settings
# ------------------------------------------------------------------------------

# First we need to generate the newly-downloaded Portuguese locale
locale-gen pt_PT.UTF-8

# Now we can make specific locale updates
update-locale LANG="pt_PT.UTF-8"
update-locale LANGUAGE="pt_PT"
update-locale LC_ALL="pt_PT.UTF-8"

# ------------------------------------------------------------------------------
# Finished
# ------------------------------------------------------------------------------

echo
echo "*** Finished with wasta-custom-${BRANCH_ID}-postinst.sh"
echo

exit 0
