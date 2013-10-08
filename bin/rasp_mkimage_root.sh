#!/bin/sh

mountpoint=
target_file=
ip=
netmask=
gateway=

for param in "$@"
do
	case $param in
		mountpoint=*)
			mountpoint=${param#mountpoint=}
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

if [ "x$mountpoint" = "x" ]
then
	echo "No mountpoint given"
	return 1
fi

if [ "x$target_file" = "x" ]
then
	echo "No target_file given"
fi

if [ "x$ip" = "x" ]
then
	echo "No IP given"
	return 1
fi
if [ "x$netmask" = "x" ]
then
	echo "No netmask given"
	return 1
fi
if [ "x$gateway" = "x" ]
then
	echo "No gateway given"
	return 1
fi

if [ "x$USER" != xroot ]
then
	echo "Must run as root"
	return 2
fi

echo mount -oloop,offset=$((122880*512)) "$target_file" "$mountpoint"
mount -oloop,offset=$((122880*512)) "$target_file" "$mountpoint"
rc=$?
echo "mount returned $rc"
echo sed -e "s/iface eth0 inet dhcp/iface eth0 inet static\n\taddress $ip\n\tnetmask $netmask\n\tgateway $gateway/" -i "${mountpoint}/etc/network/interfaces"
sed -e "s/iface eth0 inet dhcp/iface eth0 inet static\n\taddress $ip\n\tnetmask $netmask\n\tgateway $gateway/" -i "${mountpoint}/etc/network/interfaces"
rc=$?
echo "sed returned $rc"
umount "${mountpoint}"
rc=$?
echo "umount returned $rc"
