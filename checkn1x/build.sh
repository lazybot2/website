#!/bin/sh
#
# checkn1x build script
# https://asineth.gq/checkn1x
#
VERSION="1.0.1"
ROOTFS="http://cdimage.ubuntu.com/ubuntu-base/releases/18.04/release/ubuntu-base-18.04.3-base-amd64.tar.gz"

set -e -u
apt install -y wget grub-pc-bin grub-efi-amd64-bin isolinux squashfs-tools xorriso &>/dev/null
mkdir -p work/chroot
mkdir -p work/iso/casper
mkdir -p work/iso/boot/grub
wget -qO - $ROOTFS | tar -C work/chroot -xzv
mount --bind /proc work/chroot/proc
mount --bind /sys work/chroot/sys
mount --bind /dev work/chroot/dev
cp /etc/resolv.conf work/chroot/etc
cat << EOF | chroot work/chroot /bin/bash
export DEBIAN_FRONTEND=noninteractive
apt update 
apt upgrade -y
apt install -y --no-install-recommends ubuntu-standard linux-image-generic-hwe-18.04 lupin-casper language-pack-en-base software-properties-common gnupg
apt autoremove -y --purge linux-firmware  linux-modules-extra-* intel-microcode amd64-microcode
echo "deb https://assets.checkra.in/debian /" >> /etc/apt/sources.list
apt-key adv --fetch-keys "https://assets.checkra.in/debian/archive.key"
apt update
apt install -y --no-install-recommends checkra1n
apt clean
sed -i 's/COMPRESS=lz4/COMPRESS=xz/' /etc/initramfs-tools/initramfs.conf
update-initramfs -u
rm -f /etc/mtab
rm -f /etc/fstab
rm -f /etc/ssh/ssh_host*
rm -f /root/.wget-hsts
rm -f /root/.bash_history
rm -rf /var/log/*
rm -rf /var/cache/*
rm -rf /var/backups/*
rm -rf /var/lib/apt/lists/*
rm -rf /usr/share/doc/*
rm -rf /usr/share/man/*
rm -rf /usr/share/info/*
rm -rf /usr/share/icons/*
rm -rf /usr/share/themes/*
exit
EOF
mkdir -p work/chroot/etc/systemd/system/getty@tty1.service.d
cat << EOF > work/chroot/etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noissue --autologin root %I 
Type=idle
EOF
cat << EOF > work/iso/boot/grub/grub.cfg
insmod all_video
linux /boot/vmlinuz boot=casper quiet
initrd /boot/initrd.img
boot
EOF
echo "checkn1x" > work/chroot/etc/hostname
echo "checkra1n" > work/chroot/root/.bashrc
rm -f work/chroot/etc/resolv.conf
umount -lf work/chroot/proc
umount -lf work/chroot/sys
umount -lf work/chroot/dev
cp work/chroot/vmlinuz work/iso/boot
cp work/chroot/initrd.img work/iso/boot
mksquashfs work/chroot work/iso/casper/filesystem.squashfs -noappend -e boot -comp xz -Xbcj x86
grub-mkrescue -o checkn1x-$VERSION.iso work/iso
