#!/bin/bash

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

CONFIG_FILE=config

if [ ! -f $CONFIG_FILE ]; then
    echo "Please create config file" 1>&2
    exit 1
fi

source $CONFIG_FILE

ISO_FILE="mini.iso"

if [ ! -f "$ISO_FILE" ]; then
    wget -cv http://archive.ubuntu.com/ubuntu/dists/${DISTRO}/main/installer-amd64/current/images/netboot/mini.iso
fi

iso_label="PRESEED_20170322"
CUSTOM_ISO="custom.iso"
ISO_DIR="tmp_iso"
REMASTER_DIR="cd_remaster"
SEED_FILE_TEMPLATE="preseed.cfg.template"
SEED_FILE="preseed.cfg"
TMP_INITRD="tmp_initrd"

# copy iso
umount $ISO_DIR 2> /dev/null
mkdir $ISO_DIR
mkdir $REMASTER_DIR
#mkdir -p $TMP_INITRD/tmp
mount -o loop $ISO_FILE $ISO_DIR
rsync -avr $ISO_DIR/ $REMASTER_DIR/

# update initrd

#cp $ISO_DIR/initrd.gz $TMP_INITRD/
#gunzip $TMP_INITRD/initrd.gz
#cd $TMP_INITRD/tmp
#cpio -i --make-directories < ../initrd
#cp ../../$SEED_FILE .
#find ./ | cpio -H newc -o > ../initrd.gz
#cd ../..
#cp $TMP_INITRD/initrd.gz $REMASTER_DIR/

cp -v $SEED_FILE_TEMPLATE $REMASTER_DIR/$SEED_FILE

# set timeout (both for normal & uefi)
sed -i 's,timeout 0,timeout 1,g' $REMASTER_DIR/isolinux.cfg
sed -i 's,timeout 0,timeout 1,g' $REMASTER_DIR/prompt.cfg
cp $REMASTER_DIR/txt.cfg $REMASTER_DIR/isolinux.cfg
sed -i '/label cli/Q' $REMASTER_DIR/isolinux.cfg

sed -i '1s/^/set timeout=10/' $REMASTER_DIR/boot/grub/grub.cfg
sed -i '/}/Q' $REMASTER_DIR/boot/grub/grub.cfg
echo '}' >> $REMASTER_DIR/boot/grub/grub.cfg

# update variables in preseed

sed -i "s,__COUNTRY__,$COUNTRY,g" $REMASTER_DIR/$SEED_FILE
sed -i "s,__LOCALE__,$LOCALE,g" $REMASTER_DIR/$SEED_FILE
sed -i "s,__KEYMAP__,$KEYMAP,g" $REMASTER_DIR/$SEED_FILE
sed -i "s,__HOSTNAME__,$HOSTNAME,g" $REMASTER_DIR/$SEED_FILE
sed -i "s,__DOMAIN__,$DOMAIN,g" $REMASTER_DIR/$SEED_FILE
sed -i "s,__DISTRO__,$DISTRO,g" $REMASTER_DIR/$SEED_FILE
sed -i "s,__USER__,$USER,g" $REMASTER_DIR/$SEED_FILE
sed -i "s,__PASSWORD__,$PASSWORD,g" $REMASTER_DIR/$SEED_FILE
sed -i "s,__TIMEZONE__,$TIMEZONE,g" $REMASTER_DIR/$SEED_FILE
sed -i "s,__NTP__,$NTP,g" $REMASTER_DIR/$SEED_FILE
sed -i "s,__GRUB_DISK__,$GRUB_DISK,g" $REMASTER_DIR/$SEED_FILE
sed -i "s,__LVM_DISK__,$LVM_DISK,g" $REMASTER_DIR/$SEED_FILE
sed -i "s,__OS_DISK_VG__,$OS_DISK_VG,g" $REMASTER_DIR/$SEED_FILE
sed -i "s,__DATA_DISK_VG__,$DATA_DISK_VG,g" $REMASTER_DIR/$SEED_FILE
sed -i "s,__DATA_VG__,$DATA_VG,g" $REMASTER_DIR/$SEED_FILE
sed -i "s,__IP__,$IP,g" $REMASTER_DIR/$SEED_FILE
sed -i "s,__NETMASK__,$NETMASK,g" $REMASTER_DIR/$SEED_FILE
sed -i "s,__GW__,$GW,g" $REMASTER_DIR/$SEED_FILE
sed -i "s,__DNS__,$DNS,g" $REMASTER_DIR/$SEED_FILE

if [[ $BONDING == "true" ]]; then
    echo "BONDING"
    sed -i "s,__SLAVE_ETH__,$SLAVE_ETH,g" $REMASTER_DIR/$SEED_FILE
    sed -i 's,# d-i preseed/early_command string modprobe,d-i preseed/early_command string modprobe,g' $REMASTER_DIR/$SEED_FILE
fi

if [[ $DHCP == "false" ]]; then
    echo "NO DHCP"
    sed -i 's,# d-i netcfg/disable_autoconfig,d-i netcfg/disable_autoconfig,g' $REMASTER_DIR/$SEED_FILE
    sed -i 's,# d-i netcfg/get_ipaddress,d-i netcfg/get_ipaddress,g' $REMASTER_DIR/$SEED_FILE
    sed -i 's,# d-i netcfg/get_netmask,d-i netcfg/get_netmask,g' $REMASTER_DIR/$SEED_FILE
    sed -i 's,# d-i netcfg/get_gateway,d-i netcfg/get_gateway,g' $REMASTER_DIR/$SEED_FILE
    sed -i 's,# d-i netcfg/get_nameservers,d-i netcfg/get_nameservers,g' $REMASTER_DIR/$SEED_FILE
    sed -i 's,# d-i netcfg/confirm_static,d-i netcfg/confirm_static,g' $REMASTER_DIR/$SEED_FILE
#    sed -i "s,/linux --- quiet,/linux priority=critical auto=true locale=$LOCALE disable_dhcp=true disable_console-setup/charmap=UTF-8 console-setup/layoutcode=$KEYMAP console-setup/ask_detect=false url=$URL hostname=$HOSTNAME domain=$DOMAIN interface=auto get_ipaddress=$IP get_netmask=$NETMASK get_gateway=$GW get_nameservers=$DNS DEBCONF_DEBUG=developer,g" $REMASTER_DIR/boot/grub/grub.cfg

    sed -i "s,/linux --- quiet,/linux auto=true priority=critical locale=$LOCALE disable_console-setup/charmap=UTF-8 console-setup/layoutcode=$KEYMAP console-setup/ask_detect=false interface=$INTERFACE inetcfg/disable_dhcp=true netcfg/confirm_static=true netcfg/disable_autoconfig=true netcfg/get_ipaddress=$IP netcfg/get_netmask=$NETMASK netcfg/get_gateway=$GW netcfg/get_nameservers=$DNS url=$URL,g" $REMASTER_DIR/boot/grub/grub.cfg
#    sed -i "s#append #append priority=critical auto=true preseed/url=$PRESEED_URL netcfg/hostname=$HOSTNAME netcfg/domain=$DOMAIN interface=$INTERFACE_DEV netcfg/disable_dhcp=true netcfg/get_ipaddress=$INTERFACE_IP netcfg/get_netmask=$INTERFACE_NETMASK netcfg/get_gateway=$INTERFACE_GATEWAY netcfg/get_nameservers=$INTERFACE_NAMESERVERS #g" $PROJECTPATH/ubuntu-overssh-iso/txt.cfg

    sed -i "s,--- quiet,priority=critical auto=true locale=$LOCALE console-setup/charmap=UTF-8 console-setup/layoutcode=$KEYMAP console-setup/ask_detect=false pkgsel/language-pack-patterns= pkgsel/install-language-support=false interface=$INTERFACE get_ipaddress=$IP get_netmask=$NETMASK get_gateway=$GW get_nameservers=$DNS disable_dhcp=true hostname=$HOSTNAME domain=$DOMAIN url=$URL,g" $REMASTER_DIR/txt.cfg
else
    echo "DHCP"
    sed -i "s,/linux --- quiet,/linux priority=critical auto=true locale=$LOCALE console-setup/charmap=UTF-8 console-setup/layoutcode=$KEYMAP console-setup/ask_detect=false url=$URL hostname=$HOSTNAME domain=$DOMAIN interface=auto disable_autoconfig=false disable_dhcp=false DEBCONF_DEBUG=developer,g" $REMASTER_DIR/boot/grub/grub.cfg
    sed -i "s,--- quiet,priority=critical auto=true locale=$LOCALE console-setup/charmap=UTF-8 console-setup/layoutcode=$KEYMAP console-setup/ask_detect=false url=$URL hostname=$HOSTNAME domain=$DOMAIN interface=auto disable_autoconfig=false disable_dhcp=false,g" $REMASTER_DIR/txt.cfg
fi

cp $REMASTER_DIR/$SEED_FILE .

# uefi
#sed -i 's,/linux --- quiet,/linux auto=true file=/cdrom/seed.seed --- quiet,g' $REMASTER_DIR/boot/grub/grub.cfg

#sed -i "s,/linux --- quiet,/linux priority=critical auto=true locale=$LOCALE console-setup/charmap=UTF-8 console-setup/layoutcode=$KEYMAP console-setup/ask_detect=false url=$URL hostname=$HOSTNAME domain=$DOMAIN interface=auto disable_autoconfig=false disable_dhcp=false DEBCONF_DEBUG=developer,g" $REMASTER_DIR/boot/grub/grub.cfg

# normal
#sed -i "s,--- quiet,priority=critical auto=true locale=$LOCALE console-setup/charmap=UTF-8 console-setup/layoutcode=$KEYMAP console-setup/ask_detect=false pkgsel/language-pack-patterns= pkgsel/install-language-support=false interface=$INTERFACE get_ipaddress=$IP get_netmask=$NETMASK get_gateway=$GW get_nameservers=$DNS disable_dhcp=true hostname=$HOSTNAME domain=$DOMAIN url=$URL,g" $REMASTER_DIR/txt.cfg
#sed -i "s,--- quiet,priority=critical auto=true locale=$LOCALE console-setup/charmap=UTF-8 console-setup/layoutcode=$KEYMAP console-setup/ask_detect=false url=$URL hostname=$HOSTNAME domain=$DOMAIN interface=auto disable_autoconfig=false disable_dhcp=false,g" $REMASTER_DIR/txt.cfg

# Fix md5sum's
cd $REMASTER_DIR
md5sum `find -follow -type f` > md5sum.txt
cd ..

xorriso -as mkisofs \
       -iso-level 3 \
       -full-iso9660-filenames \
       -volid "${iso_label}" \
       -eltorito-boot isolinux.bin \
       -eltorito-catalog boot.cat \
       -no-emul-boot -boot-load-size 4 -boot-info-table \
       -isohybrid-mbr /usr/lib/syslinux/bios/isohdpfx.bin \
       -eltorito-alt-boot \
       -e boot/grub/efi.img \
       -no-emul-boot -isohybrid-gpt-basdat \
       -output $CUSTOM_ISO \
       $REMASTER_DIR

umount $ISO_DIR
rm -rf $ISO_DIR
rm -rf $REMASTER_DIR
rm -rf $TMP_INITRD
