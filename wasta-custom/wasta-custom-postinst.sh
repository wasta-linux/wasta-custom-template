#!/bin/bash

# ==============================================================================
# wasta-custom-${BRANCH_ID}-postinst.sh
#
#   This script is automatically run by the postinst configure step on
#       installation of wasta-custom-${BRANCH_ID}.  It can be manually re-run, but is
#       only intended to be run at package installation.
#
#   2013-12-03 rik: initial script
#   2017-12-27 jcl: rework - change LO extension to bundle method, not shared
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

BRANCH_ID=template
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
LO_54=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-5-4-*)
LO_6X=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-*)
if ! [ -e "${LO_6X[0]}" ] \
&& ! [ -e "${LO_54[0]}" ] \
&& ! [ "${REPO_SERIES}" == "bionic" ]; then
  echo "LibreOffice 5.4 PPA not found.  Adding it..."

  #key already added by wasta, so no need to use the internet with add-apt-repository
  #add-apt-repository --yes ppa:libreoffice/libreoffice-5-4
  cat << EOF >  $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-5-4-$REPO_SERIES.list
deb http://ppa.launchpad.net/libreoffice/libreoffice-5-4/ubuntu $REPO_SERIES main
# deb-src http://ppa.launchpad.net/libreoffice/libreoffice-5-4/ubuntu $REPO_SERIES main
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
# LibreOffice Extensions - bundle install (for all users)
# !! Not removed if wasta-custom-${BRANCH_ID} is uninstalled !!
#   "unopkg list --bundled" - exists since 2010
# ------------------------------------------------------------------------------
LO_EXTENSION_DIR=/usr/lib/libreoffice/share/extensions
if [ -x "${LO_EXTENSION_DIR}/" ]; then
  for EXT_FILE in "${RESOURCE_DIR}/"*.oxt ; do
    if [ -f "${EXT_FILE}" ]; then
      LO_EXTENSION=$(basename --suffix=.oxt ${EXT_FILE})
      if [ -e "${LO_EXTENSION_DIR}/${LO_EXTENSION}" ]; then
        echo "  Replacing ${LO_EXTENSION} extension"
        rm -rf "${LO_EXTENSION_DIR}/${LO_EXTENSION}"
      else
        echo "  Adding ${LO_EXTENSION} extension"
      fi
      unzip -q -d "${LO_EXTENSION_DIR}/${LO_EXTENSION}" \
                  "${RESOURCE_DIR}/${LO_EXTENSION}.oxt"
    else
      [ "$DEBUG"] && echo "DEBUG: no .oxt files to install"
    fi
  done
else
  echo "WARNING: could not find LibreOffice install..."
fi

# ------------------------------------------------------------------------------
# Schema overrides - set customized defaults for gnome software
# !! Not removed if wasta-custom-${BRANCH_ID} is uninstalled !!
# ------------------------------------------------------------------------------
SCHEMA_DIR=/usr/share/glib-2.0/schemas
RUN_COMPILE=YES
if [ -x "${SCHEMA_DIR}/" ]; then
  for OVERRIDE_FILE in "${RESOURCE_DIR}/"*.gschema.override ; do
    if [ -f "${OVERRIDE_FILE}" ]; then
      OVERRIDE=$(basename --suffix=.gschema.override ${OVERRIDE_FILE})
      if [ -e "${SCHEMA_DIR}/${OVERRIDE}.gschema.override" ]; then
        echo "  Replacing ${OVERRIDE} override"
      else
        echo "  Adding ${OVERRIDE} override"
      fi
      cp "${RESOURCE_DIR}/${OVERRIDE}.gschema.override"  "${SCHEMA_DIR}/"
      chmod 644 "${SCHEMA_DIR}/${OVERRIDE}.gschema.override"
      RUN_COMPILE=YES
    else
      [ "$DEBUG"] && echo "DEBUG: no .gschema.override files to install"
    fi
  done
else
  echo "WARNING: could not find glib schema dir..."
fi

if [ "${RUN_COMPILE^^}" == "YES" ]; then
  echo && echo "Compile changed gschema default preferences"
  [ "$DEBUG"] && glib-compile-schemas --strict ${SCHEMA_DIR}/
  glib-compile-schemas ${SCHEMA_DIR}/
fi

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
# KMFL: restart ibus if keyboards added
# ------------------------------------------------------------------------------
RESTART_IBUS=YES
[ "$RESTART_IBUS" == "YES" ] && [ $(which ibus-daemon) ] && ibus-daemon -xrd

# ------------------------------------------------------------------------------
# Set system-wide Paper Size
# ------------------------------------------------------------------------------
# Note: This sets /etc/papersize.  However, many apps do not look at this
#   location, but instead maintain their own settings for paper size :-(
paperconfig -p a4

# ------------------------------------------------------------------------------
# Change system-wide locale settings
# ------------------------------------------------------------------------------

# First we need to generate the newly-downloaded French (France) locale
#locale-gen fr_FR.UTF-8

# Now we can make specific locale updates
#update-locale LANG="fr_FR.UTF-8"
#update-locale LANGUAGE="fr_FR"
#update-locale LC_ALL="fr_FR.UTF-8"

# ------------------------------------------------------------------------------
# Ensure SSH keys have been regenerated after remastersys
#     16.04: ssh_host_dsa_key
#     18.04: ssh_host_ecdsa_key
# ------------------------------------------------------------------------------
dpkg --status openssh-server 1>/dev/null 2>&1
if [ $? == 0 ] \
&& ! [ -e /etc/ssh/ssh_host_dsa_key ] \
&& ! [ -e /etc/ssh/ssh_host_ecdsa_key ]; then
  dpkg-reconfigure openssh-server  #tested - works without conflicting with apt-get install. Also OK with apt-get update?

  if [ "$(pwd)" != "/" ]; then
    # SSH restart since probably running interactively"
    /etc/init.d/ssh restart
  fi
fi

# ------------------------------------------------------------------------------
# Finished
# ------------------------------------------------------------------------------

echo
echo "*** Finished with wasta-custom-${BRANCH_ID}-postinst.sh"
echo

exit 0
