#!/bin/bash

### Environmental variables ###
SCRIPT_DIR=$(cd $(dirname $0); pwd)
ENV_SETUP_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
ENV_SETUP_CACHE=${ENV_SETUP_ROOT}/.cache
TARGET_WALLPAPER=${ENV_SETUP_ROOT}/wallpaper/penguin_turtle.jpg

SKIP=9291428
TARGET_ISO=ubuntu-22.04.5-desktop-amd64.iso
TARGET_SQUASHFS=filesystem

TARGET_ISO_PATH=${SCRIPT_DIR}/${TARGET_ISO}
ISO_URL=https://releases.ubuntu.com/jammy/${TARGET_ISO}
### --------------------- ###

sudo apt install -y \
	apparmor \
	apparmor-utils \
	bridge-utils \
	libvirt-clients \
	libvirt-daemon-system \
	libguestfs-tools \
	qemu-kvm \
	virt-manager \
	binwalk \
	casper \
	genisoimage \
	live-boot \
	live-boot-initramfs-tools \
	squashfs-tools

sudo apt -y dist-upgrade
sudo apt -y autoremove
sudo apt clean

### Cleanup process ###
if mount | grep ${ENV_SETUP_CACHE}/edit/run > /dev/null; then
	sudo umount ${ENV_SETUP_CACHE}/edit/run
fi
if mount | grep ${ENV_SETUP_CACHE}/edit/dev > /dev/null; then
	sudo umount ${ENV_SETUP_CACHE}/edit/dev
fi
if mount | grep ${ENV_SETUP_CACHE}/edit/scripts > /dev/null; then
	sudo umount ${ENV_SETUP_CACHE}/edit/scripts
fi
if mount | grep ${ENV_SETUP_CACHE}/isomount > /dev/null; then
	sudo umount ${ENV_SETUP_CACHE}/isomount
fi

sudo rm -rf ${ENV_SETUP_CACHE}
mkdir -p ${ENV_SETUP_CACHE}/isomount
mkdir -p ${ENV_SETUP_CACHE}/extracted
cd ${ENV_SETUP_CACHE}/
### --------------------- ###

# Download ISO
if [ ! -f ${SCRIPT_DIR}/${TARGET_ISO} ]; then
    wget -O ${SCRIPT_DIR}/${TARGET_ISO} ${ISO_URL}
fi

### Extract ISO ###
sudo mount -o loop ${TARGET_ISO_PATH} ${ENV_SETUP_CACHE}/isomount
sudo rsync -a ${ENV_SETUP_CACHE}/isomount ${ENV_SETUP_CACHE}/extracted
sudo rm -rf ${ENV_SETUP_CACHE}/extracted/casper/${TARGET_SQUASHFS}.squashfs

sudo unsquashfs ${ENV_SETUP_CACHE}/isomount/casper/${TARGET_SQUASHFS}.squashfs
sudo umount ${ENV_SETUP_CACHE}/isomount

sudo mv ${ENV_SETUP_CACHE}/squashfs-root ${ENV_SETUP_CACHE}/edit

sudo mkdir -p ${ENV_SETUP_CACHE}/edit/run
sudo mkdir -p ${ENV_SETUP_CACHE}/edit/dev
sudo mkdir -p ${ENV_SETUP_CACHE}/edit/scripts

sudo mount -o bind /run/ ${ENV_SETUP_CACHE}/edit/run
sudo cp /etc/hosts ${ENV_SETUP_CACHE}/edit/etc
sudo mount --bind /dev/ ${ENV_SETUP_CACHE}/edit/dev
sudo mount --bind ${ENV_SETUP_ROOT}/scripts ${ENV_SETUP_CACHE}/edit/scripts
### --------------------- ###

### Customization point ###
sudo chroot  ${ENV_SETUP_CACHE}/edit /bin/bash -c \
"\
mount -t proc none /proc; \
mount -t sysfs none /sys; \
mount -t devpts none /dev/pts; \
sudo apt update; \
sudo apt upgrade -y; \
sudo apt dist-upgrade -y; \
sudo apt install -y locales; \
sudo locale-gen en_US en_US.UTF-8; \
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8; \
export LANG=en_US.UTF-8; \
sudo apt install -y software-properties-common; \
sudo add-apt-repository universe; \
sudo apt install -y curl lsb-release; \
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg; \
echo 'deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main' | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null; \
wget https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB; \
sudo apt-key add GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB; \
echo 'deb https://apt.repos.intel.com/openvino/2024 ubuntu22 main' | sudo tee /etc/apt/sources.list.d/intel-openvino-2024.list; \
sudo mkdir -p /etc/apt/keyrings; \
curl -sSf https://librealsense.intel.com/Debian/librealsense.pgp | sudo tee /etc/apt/keyrings/librealsense.pgp > /dev/null; \
echo 'deb [signed-by=/etc/apt/keyrings/librealsense.pgp] https://librealsense.intel.com/Debian/apt-repo `lsb_release -cs` main' | sudo tee /etc/apt/sources.list.d/librealsense.list; \
sudo apt update; \
sudo apt install -y ros-humble-desktop-full ros-humble-turtlebot3-simulations openvino-2024.6.0 librealsense2-dkms librealsense2-utils librealsense2-dev; \
umount /proc || umount -lf /proc; \
umount /sys; \
umount /dev/pts; \
exit"
### --------------------- ###

sleep 3

sudo umount ${ENV_SETUP_CACHE}/edit/run
sudo umount ${ENV_SETUP_CACHE}/edit/dev
sudo umount ${ENV_SETUP_CACHE}/edit/scripts

### Customization point ###
sudo cp ${TARGET_WALLPAPER} ${ENV_SETUP_CACHE}/edit/usr/share/backgrounds/
sudo sed -i 's/warty-final-ubuntu.png/penguin_turtle.jpg/g' ${ENV_SETUP_CACHE}/edit/usr/share/glib-2.0/schemas/10_ubuntu-settings.gschema.override


### Create ISO ###
sudo chmod 666 ${ENV_SETUP_CACHE}/extracted/isomount/casper/${TARGET_SQUASHFS}.manifest
sudo chroot ${ENV_SETUP_CACHE}/edit dpkg-query -W --showformat='${Package} ${Version}\n' > ${ENV_SETUP_CACHE}/extracted/isomount/casper/${TARGET_SQUASHFS}.manifest

# copy autoinstall.yaml to isomount root
sudo cp ${SCRIPT_DIR}/autoinstall.yaml ${ENV_SETUP_CACHE}/extracted/isomount/

sudo rm -rf ${ENV_SETUP_CACHE}/extracted/isomount/casper/${TARGET_SQUASHFS}.squashfs
sudo mksquashfs ${ENV_SETUP_CACHE}/edit ${ENV_SETUP_CACHE}/extracted/isomount/casper/${TARGET_SQUASHFS}.squashfs -comp xz
sudo du -sx --block-size=1  ${ENV_SETUP_CACHE}/edit | cut -f1 | sudo tee ${ENV_SETUP_CACHE}/extracted/isomount/casper/${TARGET_SQUASHFS}.size > /dev/null

sudo dd bs=1 count=446 if=${TARGET_ISO_PATH} of=${ENV_SETUP_CACHE}/mbr.img
sudo dd bs=512 count=10072 skip=${SKIP} if=${TARGET_ISO_PATH} of=${ENV_SETUP_CACHE}/EFI.img
EFI_SIZE=$(stat -c %s ${ENV_SETUP_CACHE}/EFI.img)
sudo xorriso -indev ${TARGET_ISO_PATH} -report_el_torito cmd

CURRENT_DIR=$(realpath ./)
sudo xorriso \
	-outdev ${ENV_SETUP_CACHE}/MyDistribution.iso \
	-map ${ENV_SETUP_CACHE}/extracted/isomount / \
	-- -volid "Ubuntu Remix amd64" \
	-boot_image grub \
	grub2_mbr=${ENV_SETUP_CACHE}/mbr.img \
	-boot_image any partition_table=on \
	-boot_image any partition_cyl_align=off \
	-boot_image any partition_offset=16 \
	-boot_image any mbr_force_bootable=on \
	-append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b ${ENV_SETUP_CACHE}/EFI.img \
	-boot_image any appended_part_as=gpt \
	-boot_image any iso_mbr_part_type=a2a0d0ebe5b9334487c068b6b72699c7 \
	-boot_image any cat_path='boot.catalog' \
	-boot_image grub bin_path='boot/grub/i386-pc/eltorito.img' \
	-boot_image any platform_id=0x00 \
	-boot_image any emul_type=no_emulation \
	-boot_image any load_size=2048 \
	-boot_image any boot_info_table=on \
	-boot_image grub grub2_boot_info=on \
	-boot_image any next \
	-boot_image any efi_path=--interval:appended_partition_2:all:: \
	-boot_image any platform_id=0xef \
	-boot_image any emul_type=no_emulation \
	-boot_image any load_size=${EFI_SIZE}

### --------------------- ###

sudo mv ${ENV_SETUP_CACHE}/MyDistribution.iso ${ENV_SETUP_ROOT}/
echo "Created ${ENV_SETUP_ROOT}/MyDistribution.iso"