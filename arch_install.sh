while true
    do
        read -erp "enter new user name: " user

        if [ -z ${user} ]
            then
                echo "user name cannot be blank"
                continue
        fi
        if [ ${user} == "root" ]
            then
                echo "user name cannot be root"
                continue
        fi
        break
done

while true
    do
        read -serp "enter new password: " password
        printf "\n"

        if [ -z ${password} ]
            then
                echo "password cannot be blank"
                continue
        fi
        break
done

echo $user > ~/ARCHLINUX_USERNAME.txt
echo "username saved to ~/ARCHLINUX_USERNAME.txt"
echo
echo "do not change the above file, it will be used to log-in to the archlinux container"
echo

if [[ -e ~/ARCHLINUX/TAR/archlinux-bootstrap-x86_64.tar.gz ]]
    then
        echo "skipping download"
    else
        mkdir -p ~/ARCHLINUX/TAR > /dev/null 2>&1
        cd ~/ARCHLINUX/TAR
        curl -L -O https://mirror.aarnet.edu.au/pub/archlinux/iso/2022.07.01/archlinux-bootstrap-x86_64.tar.gz
fi

if [[ -e ~/ARCHLINUX/ROOTFS ]]
    then
        echo "removing old rootfs, this requires root permissions"
        sudo rm -rf ~/ARCHLINUX/ROOTFS
fi
mkdir -p ~/ARCHLINUX/ROOTFS
cd ~/ARCHLINUX/ROOTFS
echo "extracting rootfs, this requires root permissions"
sudo tar xzf ~/ARCHLINUX/TAR/archlinux-bootstrap-x86_64.tar.gz --numeric-owner

if [[ -e ~/ARCHLINUX/CHROOT ]]
    then
        if [[ -e ~/ARCHLINUX/CHROOT/ARCH_CHROOT ]]
            then
                echo "unbinding existing arch chroot, this requires root permissions"
                sudo umount ~/ARCHLINUX/CHROOT/ARCH_CHROOT
                rm -rf ~/ARCHLINUX/CHROOT/ARCH_CHROOT
        fi
fi

rm -rf ~/ARCHLINUX/CHROOT
mkdir -p ~/ARCHLINUX/CHROOT
cd ~/ARCHLINUX/CHROOT
mkdir -p ~/ARCHLINUX/CHROOT/ARCH_CHROOT
echo "binding arch chroot, this requires root permissions"
sudo mount --bind ~/ARCHLINUX/ROOTFS/root.x86_64 ~/ARCHLINUX/CHROOT/ARCH_CHROOT
echo "binded arch chroot"
echo "setting root password, this requires root permissions"
sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "echo -e \"root\nroot\" | passwd > /dev/null 2>&1"
echo "the password for the root user is 'root'"
echo "creating user: $user, this requires root permissions"
sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "useradd -m $user ; echo -e \"$password\n$password\" | passwd $user > /dev/null 2>&1"

sudo nano ~/ARCHLINUX/CHROOT/ARCH_CHROOT/etc/pacman.d/mirrorlist
sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "pacman-key --init"
sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "pacman-key --populate"
sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "pacman -Sy"
sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "pacman -S sudo"

