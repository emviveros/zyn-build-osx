#!/bin/bash
: ${OUTDIR="/tmp/"}
: ${PRODUCT_NAME="ZynAddSubFx"}
: ${ICON_FILE="ZynAddSubFx.icns"}

set -e

pushd "`/usr/bin/dirname \"$0\"`" > /dev/null; this_script_dir="`pwd`"; popd > /dev/null

test -n $BUNDLEDIR
test -d ${BUNDLEDIR}/inst

##############################################################################
cd $HOME/src/zyn_build_x86_64/zynaddsubfx/build
VERSION=`git describe --tags | sed 's/-g[a-f0-9]*$//'`
##############################################################################

if test -f /Developer/usr/bin/packagemaker ; then
	echo "calling packagemaker"
	/Developer/usr/bin/packagemaker -v \
		--out "${OUTDIR}${PRODUCT_NAME}-${VERSION}.pkg" \
		--title "${PRODUCT_NAME} Plugins" \
		--root ${BUNDLEDIR}/inst/ \
		--install-to /Library/Audio/Plug-Ins/ \
		--no-relocate --root-volume-only \
		--version "$VERSION" \
		--target 10.5 --domain system --id com.github.zynaddsubfx.pkg

	ls -l "${OUTDIR}${PRODUCT_NAME}-${VERSION}.pkg"
else
	echo "--!!!--  Skipped Package"
fi

##############################################################################

UC_DMG="${OUTDIR}${PRODUCT_NAME}-${VERSION}.dmg"
DMGBACKGROUND=${this_script_dir}/dmgbg.png
VOLNAME=$PRODUCT_NAME-${VERSION}
EXTRA_SPACE_MB=5

DMGMEGABYTES=$[ `du -sck "${BUNDLEDIR}/inst" | tail -n 1 | cut -f 1` * 1024 / 1048576 + $EXTRA_SPACE_MB ]
echo "DMG MB = " $DMGMEGABYTES

MNTPATH=`mktemp -d -t mntpath`
TMPDMG=`mktemp -t tmpdmg`
ICNSTMP=`mktemp -t appicon`

trap "rm -rf $MNTPATH $TMPDMG ${TMPDMG}.dmg $ICNSTMP $BUNDLEDIR" EXIT

rm -f "$UC_DMG" "$TMPDMG" "${TMPDMG}.dmg" "$ICNSTMP ${ICNSTMP}.icns ${ICNSTMP}.rsrc"
rm -rf "$MNTPATH"
mkdir -p "$MNTPATH"

TMPDMG="${TMPDMG}.dmg"

hdiutil create -megabytes $DMGMEGABYTES "$TMPDMG"
DiskDevice=$(hdid -nomount "$TMPDMG" | grep Apple_HFS | cut -f 1 -d ' ')
newfs_hfs -v "${VOLNAME}" "${DiskDevice}"
mount -t hfs -o nobrowse "${DiskDevice}" "${MNTPATH}"

cp -a "${BUNDLEDIR}/inst/LV2" "${MNTPATH}/"
cp -a "${BUNDLEDIR}/inst/VST" "${MNTPATH}/"

mkdir "${MNTPATH}/.background"
cp -vi ${DMGBACKGROUND} "${MNTPATH}/.background/dmgbg.png"

echo "setting DMG background ..."

if test $(sw_vers -productVersion | cut -d '.' -f 2) -lt 9; then
	# OSX ..10.8.X
	DISKNAME=${VOLNAME}
else
	# OSX 10.9.X and later
	DISKNAME=`basename "${MNTPATH}"`
fi

echo '
   tell application "Finder"
     tell disk "'${DISKNAME}'"
	   open
	   delay 1
	   set current view of container window to icon view
	   set toolbar visible of container window to false
	   set statusbar visible of container window to false
	   set the bounds of container window to {400, 200, 800, 425}
	   set theViewOptions to the icon view options of container window
	   set arrangement of theViewOptions to not arranged
	   set icon size of theViewOptions to 64
	   set background picture of theViewOptions to file ".background:dmgbg.png"
	   set position of item "LV2" of container window to {100, 100}
	   set position of item "VST" of container window to {310, 100}
	   close
	   open
	   update without registering applications
	   delay 5
	   eject
     end tell
   end tell
' | osascript || {
	echo "Failed to set background/arrange icons"
	umount "${DiskDevice}" || true
	hdiutil eject "${DiskDevice}"
	exit 1
}

set +e
chmod -Rf go-w "${MNTPATH}"
set -e
sync

echo "unmounting the disk image ..."
## Umount the image ('eject' above may already have done that)
umount "${DiskDevice}" || true
hdiutil eject "${DiskDevice}" || true

## Create a read-only version, use zlib compression
echo "compressing Image ..."
hdiutil convert -format UDZO "${TMPDMG}" -imagekey zlib-level=9 -o "${UC_DMG}"
## Delete the temporary files
rm "$TMPDMG"
rm -rf "$MNTPATH"

echo "setting file icon ..."

cp ${this_script_dir}/${ICON_FILE} ${ICNSTMP}.icns
sips -i ${ICNSTMP}.icns
DeRez -only icns ${ICNSTMP}.icns > ${ICNSTMP}.rsrc
Rez -append ${ICNSTMP}.rsrc -o "$UC_DMG"
SetFile -a C "$UC_DMG"

rm ${ICNSTMP}.icns ${ICNSTMP}.rsrc
rm -rf $BUNDLEDIR

echo
echo "packaging succeeded:"
ls -l "$UC_DMG"
echo "Done."
