#!/bin/sh
# First, check to see if we're root
#read -p '"Hit Enter to install MXB Keyboards, else Ctrl-C - Pluse "Enter" para instalar teclados MXB, Si no, Ctrl-C "' evar

if ! [ $(id -u) = 0 ]; then
	 exec sudo -- "$0" "$@"	# If not, re-run the command as root
fi
# Assure that all scripts are executable

chmod +x /usr/share/wasta-custom-mxb/uninstallmxbkb.sh

echo "Source files installed."
# Check to see if the mx is already listed in the list 
if grep -q "mx_enus" /usr/share/X11/xkb/rules/evdev.lst
  then echo "List file already contains entry."
else
	if [ ! -f /usr/share/mxb/X11/xkb/rules/evdev.lst ];
		then
		mkdir -p /usr/share/mxb/X11/xkb/rules /usr/share/mxb/ibus/component 
		sed -f /usr/share/wasta-custom-mxb/edevlst.sed /usr/share/X11/xkb/rules/evdev.lst > /usr/share/wasta-custom-mxb/outlst.lst 					#newest line
	      cat /usr/share/X11/xkb/rules/evdev.lst >/usr/share/mxb/X11/xkb/rules/evdev_orig.lst 	#backup original
	      cat /usr/share/wasta-custom-mxb/outlst.lst > /usr/share/X11/xkb/rules/evdev.lst					#replace file
		echo "Modified evdev.lst. Original version stored as /usr/share/mxb/X11/xkb/rules/evdev_orig.lst."
	fi
fi
# Check to see if the mx is already listed in the list 
if grep -q "<description>English (MXB AltGr dead keys)</description>" /usr/share/X11/xkb/rules/evdev.xml
        then echo "XML List already contains entry."
else
	sed -f /usr/share/wasta-custom-mxb/edevxml.sed /usr/share/X11/xkb/rules/evdev.xml > /usr/share/wasta-custom-mxb/outxml.xml
        cat /usr/share/X11/xkb/rules/evdev.xml >/usr/share/mxb/X11/xkb/rules/evdev_orig.xml
        cat /usr/share/wasta-custom-mxb/outxml.xml > /usr/share/X11/xkb/rules/evdev.xml
        echo "Modified evdev.xml. Original version stored as /usr/share/mxb/X11/xkb/rules/evdev_orig.xml."
fi

#	Make it loadable by ibus
if [ -f /usr/share/ibus/component/simple.xml ];
   then 
	if grep -q "<description>US English (MXB AltGr dead keys)</description>" /usr/share/ibus/component/simple.xml
	then echo "ibus simple.xml already contains entry."
	else	cat /usr/share/ibus/component/simple.xml > /usr/share/mxb/ibus/component/simple_orig.xml
		sed -f /usr/share/wasta-custom-mxb/simplexml.sed /usr/share/ibus/component/simple.xml > /usr/share/wasta-custom-mxb/outsimple.xml
	      cat /usr/share/wasta-custom-mxb/outsimple.xml > /usr/share/ibus/component/simple.xml
		echo "Ibus found. /usr/share/ibus/component/simple.xml replaced. Original saved as simple_orig.xml."-
	fi


	# Add the KBs to the ibus dconf key /desktop/ibus/general/xkb-latin-layouts which permits them to update  - Oct 2015
	if [ ! -f /usr/share/mxb/ibus/dconf/xkb-latin-layouts ];	#Have we already been here?
		then	
			mkdir /usr/share/mxb/ibus/dconf
			gsettings get org.freedesktop.ibus.general xkb-latin-layouts > /usr/share/mxb/ibus/dconf/xkb-latin-layouts
	fi
	if ! grep -q "mx_es2mx" /usr/share/mxb/ibus/dconf/xkb-latin-layouts
		then
			NKEY=`sed s/]/,\ \'mx_enus\',\ \'mx_es1mx\',\ \'mx_es2mx\']/ < /usr/share/mxb/ibus/dconf/xkb-latin-layouts` 
			echo $NKEY
			gsettings set org.freedesktop.ibus.general xkb-latin-layouts "$NKEY"
			if [ $? -eq 0 ]; then
			    echo "dconf keys updated - original key stored at /usr/share/mxb/ibus/dconf/xkb-latin-layouts"
			else
    				rm -r /usr/share/mxb/ibus/dconf	#we failed to set it
				echo "Failed to install MXB KBs in dconf keys."
			fi
	fi
fi



echo "MXB Keyboards are installed."
echo "Teclados de MXB estan instalados." 
#read -p 'Hit "Enter" to continue. - Pulse "Enter" para continuar."' evar

