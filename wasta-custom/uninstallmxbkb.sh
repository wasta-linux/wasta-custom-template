#!/bin/sh

# First, check to see if we're root
if ! [ $(id -u) = 0 ]; then
	 exec sudo -- "$0" "$@"	# If not, re-run the command as root
fi
#remove symbol file
rm /usr/share/X11/xkb/symbols/mx_enus
rm /usr/share/X11/xkb/symbols/mx_es1mx
rm /usr/share/X11/xkb/symbols/mx_es2mx
echo "Source files removed."

# Check to see if the mx is already listed in the list 
if grep -q "mx_enus              English (MXB AltGr dead keys)" /usr/share/X11/xkb/rules/evdev.lst
  then echo "List file contains entry."
        cat /usr/share/mxb/X11/xkb/rules/evdev_orig.lst >/usr/share/X11/xkb/rules/evdev.lst
        echo "Orignal List file replaced."
else
        echo "List file unchanged."
fi
# Check to see if the mx is already listed in the list 
if grep -q "<description>English (MXB AltGr dead keys)</description>" /usr/share/X11/xkb/rules/evdev.xml
        then echo "XML file contains entry."
        cat /usr/share/mxb/X11/xkb/rules/evdev_orig.xml >/usr/share/X11/xkb/rules/evdev.xml
                echo "Orignal XML file replaced."
else
        echo "evdev.xml unchanged."
fi
if [ -f /usr/share/mxb/ibus/component/simple_orig.xml ];
   then
	cat /usr/share/mxb/ibus/component/simple_orig.xml > /usr/share/ibus/component/simple.xml
	echo "Original XML ibus list replaced."
fi

# Return ibus to original state

if [ -f /usr/share/mxb/ibus/dconf/xkb-latin-layouts ];
	then
	NKEY='cat /usr/share/mxb/ibus/dconf/xkb-latin-layouts'
	gsettings set org.freedesktop.ibus.general xkb-latin-layouts "$NKEY"
fi
 
# Remove our keyboards from ibus

NKEY=`gsettings get org.freedesktop.ibus.general preload-engines | sed s/\'xkb:mx_enus::eng\'// `
NKEY=`echo $NKEY | sed s/\'xkb:mx_es[12]mx::spa\'//`
NKEY=`echo $NKEY | sed s/\'xkb:mx_es[12]mx::spa\'//`
#NKEY=`echo $NKEY | sed s/,\ //`
#NKEY=`echo $NKEY | sed s/,\ //`
#NKEY=`echo $NKEY | sed s/,\ //`

# If they were only using our keyboards, leave them with something
#if [ $NKEY == "\[\]" ];
#	then NKEY="['xkb:latam::spa', 'xkb:us::eng']"
#fi
echo $NKEY
#gsettings set org.freedesktop.ibus.general preload-engines "$NKEY"
#gsettings set org.freedesktop.ibus.general engines-order "$NKEY"

#rm -R /usr/share/mxb

echo "MXB Keyboard(s) uninstalled. Restart or logout/login to see changes." 
#read -p 'Hit "Enter" to continue. - Pulse "Enter" para continuar."' evar
