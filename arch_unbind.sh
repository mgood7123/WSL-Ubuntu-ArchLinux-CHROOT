if [[ -e ~/ARCHLINUX/CHROOT ]]
    then
        if [[ -e ~/ARCHLINUX/CHROOT/ARCH_CHROOT ]]
            then
                echo "unbinding existing arch chroot, this requires root permissions"
                sudo umount ~/ARCHLINUX/CHROOT/ARCH_CHROOT
                rm -rf ~/ARCHLINUX/CHROOT/ARCH_CHROOT
        fi
    else
        echo "arch chroot does not exist, please run arch_install.sh"
        exit
fi
