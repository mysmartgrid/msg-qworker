#!/bin/bash -x

exec >> /tmp/mkimage.log 2>&1
basedir=/var/tmpdata

cd ${basedir}

echo "Start mkimage " `date`
echo "My id is: " `id`
template_file=
target_file=
ip=
netmask=
gateway=

for param in "$@"
do
	case $param in
		template=*)
			template_file=${param#template=}
			;;

		target=*)
			target_file=${param#target=}
			;;

		ip=*)
			ip=${param#ip=}
			;;

		netmask=*)
			netmask=${param#netmask=}
			;;

		gateway=*)
			gateway=${param#gateway=}
			;;
	esac
done

if [ "x$template_file" = "x" ]
then
	echo "No template given"
	exit 1
fi
if [ "x$ip" = "x" ]
then
	echo "No IP given"
	exit 1
fi
if [ "x$netmask" = "x" ]
then
	echo "No netmask given"
	exit 1
fi
if [ "x$gateway" = "x" ]
then
	echo "No gateway given"
	exit 1
fi

if ! [ -f "$template_file" ]
then
	echo "Template does not exist"
	exit 3
fi

if [ "x$target_file" = "x" ]
then
	target_file="image_$ip.img"
fi

dir=`mktemp -d`
mkdir -p ${basedir}/${target_file}

cp "$template_file" "${basedir}/${target_file}/rasp-image.img"

sudo /usr/local/bin/rasp_mkimage_root.sh target=${basedir}/${target_file}/rasp-image.img mountpoint=${dir} ip=${ip} netmask=${netmask} gateway=${gateway}
rmdir "$dir"
cd ${target_file}
zip -r ${target_file}.zip rasp-image.img 
echo rsync
scp -vp ${target_file}.zip www-data@dev3.mysmartgrid.de:/var/tmpdata/rasp-images
touch ${target_file}.done
scp -vp ${target_file}.done www-data@dev3.mysmartgrid.de:/var/tmpdata/rasp-images
echo rsync done `date`
cd ..
rm -rf ${target_file}
