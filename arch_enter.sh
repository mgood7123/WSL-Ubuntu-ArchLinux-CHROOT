user=""
password=""
if [[ -e ~/ARCHLINUX_USERNAME.txt ]]
    then
        user=$(cat ~/ARCHLINUX_USERNAME.txt)
    else
        echo "username not set or has been deleted, please run arch_install.sh"
        exit
fi

if [[ -e ~/ARCHLINUX/CHROOT ]]
    then
        if [[ -e ~/ARCHLINUX/CHROOT/ARCH_CHROOT ]]
            then
                echo "unbinding existing arch chroot, this requires root permissions"
                sudo umount ~/ARCHLINUX/CHROOT/ARCH_CHROOT
                rm -rf ~/ARCHLINUX/CHROOT/ARCH_CHROOT
        fi
        mkdir -p ~/ARCHLINUX/CHROOT/ARCH_CHROOT > /dev/null 2>&1
        echo "binding arch chroot, this requires root permissions"
        sudo mount --bind ~/ARCHLINUX/ROOTFS/root.x86_64 ~/ARCHLINUX/CHROOT/ARCH_CHROOT
        echo "binded arch chroot"
        sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT su - $user
    else
        echo "arch chroot does not exist, please run arch_install.sh"
        exit
fi
