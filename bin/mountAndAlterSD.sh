## Mount a Raspberry Pi SD image and do stuff to it.
# 
if [ $# -ne 3 ]
then
	echo "USAGE: $0 IMGPATH MNTPOINT USER"
	echo
	echo 'Where IMGPATH is the path to the .img file,'
	echo '      MNTPOINT is the place to mount it (like /mnt/sdcard,'
	echo '  and USER is the user on the SD image (probably "pi").'
	exit
fi
set -e
# imgPath=/media/tsbertalan/Acomdata/robotics/doctoredSD.img
imgPath=$1
# mntPoint=/mnt/img
mntPoint=$2
user=$3

echo Get information about the starting image file--we want to mount the second partition.
sudo fdisk -lu $imgPath > /tmp/fdisk.out
bytesPerSector=`grep "sectors of" /tmp/fdisk.out | awk "{ print \\$7 }"`
grep "img2" /tmp/fdisk.out
startSector=`grep "img2" /tmp/fdisk.out | awk "{ print \\$2 }"`
startByte=$(( $bytesPerSector * $startSector ))
echo "$bytesPerSector bytes per sector times $startSector sectors equals $startByte bytes at start of partition."

echo Mount the second partition.
sudo mount -o loop,offset=$startByte $imgPath $mntPoint

echo Add things to partition mounted at $mntPoint.
sudo `dirname $0`/doctorSDcard.sh $mntPoint $user

echo Unmount $mntPoint.
sudo umount $mntPoint

