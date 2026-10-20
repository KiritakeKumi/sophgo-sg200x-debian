#!/bin/sh
#
set -ex

BOARD=$(cat /tmp/install/board)
HOSTNAME=$(cat /tmp/install/hostname)
STORAGETYPE=$(cat /tmp/install/storage)
SUITE=$(cat /tmp/install/suite)
# vendor: the Sophgo 5.10 kernel, mainline: upstream Linux (the files do not exist in older builds)
KERNEL=$(cat /tmp/install/kernel 2>/dev/null || echo vendor)


export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C LANGUAGE=C LANG=C

/var/lib/dpkg/info/base-passwd.preinst install || true
/var/lib/dpkg/info/sgml-base.preinst install || true

mkdir -p /etc/sgml
mount proc -t proc /proc
mount -B sys /sys
mount -B run /run
mount -B dev /dev
#mount devpts -t devpts /dev/pts
dpkg --configure -a

unset DEBIAN_FRONTEND DEBCONF_NONINTERACTIVE_SEEN

#
# Change root password to 'rv'
#
usermod --password "$(echo rv | openssl passwd -1 -stdin)" root

#
# Add a new user debian and its passwd is `rv`
#
mkdir -p /home/debian
useradd --password dummy \
    -G cdrom,floppy,sudo,audio,dip,video,plugdev \
    --home-dir /home/debian --shell /bin/bash debian || true
chown debian:debian /home/debian
# Set password to 'debian'
usermod --password "$(echo rv | openssl passwd -1 -stdin)" debian || true

# Set up fstab
cat > /etc/fstab <<EOF
# <file system> <mount point>   <type>  <options>                 <dump>  <pass>
/dev/root       /               auto    defaults                  1       1
EOF

if [ "$STORAGETYPE" = "sd" ]; then
  cat >> /etc/fstab <<EOF
/dev/mmcblk0p1  /boot           auto    defaults                  1       2
EOF
fi



# Grow the root partition and its ext4 filesystem to fill the storage. Used on the first boot, works for SD cards and
# eMMC, MBR and GPT, and does nothing when the partition already fills the disk.
# The root device is looked up by its major:minor, because / is mounted from "/dev/root", which has no device node.
cat > /usr/local/sbin/grow-rootfs <<'XEOF'
#!/bin/sh
MNT=${1:-/}
fstype=$(findmnt -no FSTYPE "$MNT") || exit 0
[ "$fstype" = ext4 ] || exit 0
majmin=$(findmnt -no MAJ:MIN "$MNT" | tr -d " ")
sys=$(readlink -f "/sys/dev/block/$majmin")
if [ ! -r "$sys/partition" ]; then
    echo "the root filesystem is not on a partition, nothing to do"
    exit 0
fi
partnum=$(cat "$sys/partition")
part=/dev/$(basename "$sys")
diskname=$(basename "$(dirname "$sys")")
disk=/dev/$diskname
end=$(( $(cat "$sys/start") + $(cat "$sys/size") ))
total=$(cat "/sys/block/$diskname/size")
if [ $((total - end)) -gt 4096 ]; then
    # parted asks for a confirmation to resize a partition that is in use, and -s answers that with No
    parted -s -f "$disk" resizepart "$partnum" 100% ||
        echo Yes | parted ---pretend-input-tty "$disk" resizepart "$partnum" 100% || true
    udevadm settle 2>/dev/null || true
fi
resize2fs "$part"
XEOF
chmod 755 /usr/local/sbin/grow-rootfs

#regenerate SSH keys on first boot
cat > /etc/systemd/system/finalize-image.service <<EOF
[Unit]
Description=Finalize the Image
Before=ssh.service

[Service]
Type=oneshot
ExecStartPre=-/usr/local/sbin/grow-rootfs
ExecStartPre=-/bin/dd if=/dev/hwrng of=/dev/urandom count=1 bs=4096
ExecStartPre=-/bin/sh -c "/bin/rm -f -v /etc/ssh/ssh_host_*_key*"
ExecStart=/usr/bin/ssh-keygen -A -v
ExecStartPost=/bin/systemctl disable finalize-image

[Install]
WantedBy=multi-user.target
EOF

cat /etc/systemd/system/finalize-image.service

apt install -y -f /tmp/install/*.deb


# change device tree
echo "===== ln -s dtb files ====="
file_prefix="/usr/lib/linux-image-*"

file_path=$(ls -d $file_prefix)

if [ -e "$file_path" ]; then
  echo "File found: $file_path"
  lib_dir=$file_path
else
  echo "File not found: $file_path"
fi

kernel_image=${lib_dir##*/}

# set default dtb file, please verify your board version
mkdir -p /boot/fdt/${kernel_image}

if [ "$KERNEL" = "mainline" ]; then
  # the dtbs and overlays are in the sophgo directory, keep it, the dtb to use is selected with U_BOOT_FDT below
  cp -a ${lib_dir}/sophgo /boot/fdt/${kernel_image}/
  MAINLINE_DTB=$(cat /tmp/install/dtb)
  test -f /boot/fdt/${kernel_image}/${MAINLINE_DTB}
  FDT_DIR_NAME="linux-image-"
else
  cp ${lib_dir}/cvitek/*.dtb /boot/fdt/${kernel_image}/
  FDT_DIR_NAME="linux-image-$BOARD-"
fi


cat /boot/extlinux/extlinux.conf

if [ "$STORAGETYPE" = "sd" ]; then
  ROOT_DEVICE=/dev/mmcblk0p2
elif [ "$KERNEL" = "mainline" ]; then
  # the eMMC of the Duo S is mmc1 in the mainline device tree, mmc0 is the SD card slot
  ROOT_DEVICE=/dev/mmcblk1p1
else
  ROOT_DEVICE=/dev/mmcblk0p1
fi
sed -i -i "s|#U_BOOT_PARAMETERS=\".*\"|U_BOOT_PARAMETERS=\"console=ttyS0,115200 earlycon=sbi root=$ROOT_DEVICE rootwait rw\"|" /etc/default/u-boot

sed -i -e 's|#U_BOOT_SYNC_DTBS=".*"|U_BOOT_SYNC_DTBS="true"|' /etc/default/u-boot
#doing this dance, as in the chroot, / and /boot are same filesystem, so u-boot-update doesn't setup correctly
echo "U_BOOT_FDT_DIR=\"/usr/lib/$FDT_DIR_NAME\"" >> /etc/default/u-boot
if [ "$KERNEL" = "mainline" ]; then
  # one specific device tree of the package, the U-Boot environment of the vendor bootloader would look for another name
  echo "U_BOOT_FDT=\"$MAINLINE_DTB\"" >> /etc/default/u-boot
fi
u-boot-update
# "fdtdir" is used by the vendor kernel, "fdt" by the mainline kernel
if [ "$STORAGETYPE" = "sd" ]; then
  sed -i -E 's#^([[:space:]]*fdt(dir)? )/usr/lib/#\1/fdt/#' /boot/extlinux/extlinux.conf
  sed -i -e 's|linux /boot/|linux /|' /boot/extlinux/extlinux.conf
  sed -i -e "s|U_BOOT_FDT_DIR=\".*\"|U_BOOT_FDT_DIR=\"/fdt/$FDT_DIR_NAME\"|" /etc/default/u-boot
else 
  sed -i -E 's#^([[:space:]]*fdt(dir)? )/usr/lib/#\1/boot/fdt/#' /boot/extlinux/extlinux.conf
fi

cat /boot/extlinux/extlinux.conf

# The mainline kernel has the AIC8800 drivers as modules, nothing loads them by itself
if [ "$KERNEL" = "mainline" ] && [ "$(cat /tmp/install/aic8800 2>/dev/null)" = "yes" ]; then
  mkdir -p /etc/modprobe.d /etc/modules-load.d
  cat > /etc/modprobe.d/aic8800.conf <<EOF
# aic8800_bsp powers the chip and uploads its firmware, the wifi and bluetooth drivers are useless before it has run
softdep aic8800_fdrv pre: aic8800_bsp
softdep aic8800_btlpm pre: aic8800_bsp
EOF
  cat > /etc/modules-load.d/aic8800.conf <<EOF
aic8800_bsp
aic8800_fdrv
EOF
fi

# Set hostname
cat /tmp/install/hostname > /etc/hostname

# 
cat >> /etc/hosts << EOF
127.0.0.1      ${HOSTNAME} 
EOF

# 
# Enable system services
#
systemctl enable finalize-image.service
if [ -f /tmp/install/systemd-enable ]; then
  systemctl enable `cat /tmp/install/systemd-enable`
fi

# Update source list 

# mmdebstrap may have written its own (possibly deb822) sources, drop them so entries aren't duplicated
rm -f /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources

# apt-key is gone in APT 3.0 (Debian 13), so use a signed-by keyring instead
mkdir -p /etc/apt/keyrings
cp /tmp/install/public-key.asc /etc/apt/keyrings/sophgo.asc

cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian ${SUITE} main non-free-firmware
EOF
if [ "$SUITE" != "sid" ] && [ "$SUITE" != "unstable" ]; then
  cat >> /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian ${SUITE}-updates main non-free-firmware
deb http://deb.debian.org/debian-security ${SUITE}-security main non-free-firmware
EOF
fi
cat >> /etc/apt/sources.list <<EOF
deb [signed-by=/etc/apt/keyrings/sophgo.asc] https://sophgo.my-ho.st:8443/ debian sophgo
EOF

echo "/boot/uboot.env	0x0000          0x20000" > /etc/fw_env.config
mkenvimage -s 0x20000 -o /boot/uboot.env /etc/u-boot-initial-env


#
# Clean apt cache on the system
#
apt-get clean


rm -rf /var/cache/*
find /var/lib/apt/lists -type f -not -name '*.gpg' -print0 | xargs -0 rm -f
find /var/log -type f -print0 | xargs -0 truncate --size=0
