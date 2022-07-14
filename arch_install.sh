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
sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "useradd -g users -G wheel -m $user ; echo -e \"$password\n$password\" | passwd $user > /dev/null 2>&1"
echo "created user: $user"

sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "sed 's/#Server = http:\/\/archlinux.mirror.digitalpacific.com.au/Server = http:\/\/archlinux.mirror.digitalpacific.com.au/g' /etc/pacman.d/mirrorlist > /etc/pacman.d/mirrorlist.new ; mv /etc/pacman.d/mirrorlist.new /etc/pacman.d/mirrorlist"

sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "pacman-key --init"
sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "pacman-key --populate"
sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "pacman -Sy"
sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "pacman -S sudo nano curl jq pacman-contrib --noconfirm"

echo "installing pacman-mirrorlist"
cat <<EOF > ~/ARCHLINUX/pacman-mirrorlist
#!/bin/sh
# /etc/pacman.d/hooks/mirrorlist.hook
#
# To prevent the systemd unit above from running potentially any code that could
# be put into this file, copy the script to the secure /usr/local/bin directory.

# Exit immediately if a command exits with a non-zero exit status.
set -e

# Fail-check: make sure you have root permissions.
if [ ! -w /etc/pacman.d/mirrorlist ]; then
   printf '%s\n' ':: Error: missing required root permissions.'
   exit 1
fi

# Mirrorlist status from the last 24 hours.
URL='https://archlinux.org/mirrors/status/json/'

# Return only secure mirrors from selected countries.
FILTER='.urls | [.[] | select(.protocol == "https")]
              | [.[] | select(.completion_pct == 1.0)]
              | [.[] | select(.country_code == "CH", .country_code == "AT",
                              .country_code == "DK", .country_code == "FI",
                              .country_code == "IS", .country_code == "LU",
                              .country_code == "NL", .country_code == "NO",
                              .country_code == "SI")]
              | .[] | "## \(.country)\nServer = \(.url)$repo/os/$arch"'

# Fetch and filter the mirrors, then rank them by connection and opening speed.
curl -qs "$URL" | jq -r "$FILTER" | rankmirrors -v - > /tmp/mirrorlist

# Fail-check: make sure the new mirrorlist is not empty.
if [ -s /tmp/mirrorlist ]; then
   # Backup previous mirrorlist and move over the new one.
   mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.previous
   mv /tmp/mirrorlist /etc/pacman.d/mirrorlist

   # Remove mirrorlist.pacnew created during pacman-mirrorlist upgrade.
   [ -f /etc/pacman.d/mirrorlist.pacnew ] && rm /etc/pacman.d/mirrorlist.pacnew
else
   printf '%s\n' "      - built an empty mirrorlist, check the script's FILTER"
fi

# Exit with successful status to satisfy the pacman hook.
exit 0
EOF

sudo mv ~/ARCHLINUX/pacman-mirrorlist ~/ARCHLINUX/CHROOT/ARCH_CHROOT/usr/local/bin/pacman-mirrorlist

chmod +x ~/ARCHLINUX/CHROOT/ARCH_CHROOT/usr/local/bin/pacman-mirrorlist
echo "installed pacman-mirrorlist"

echo "installing mirrorlist.hook"
cat <<EOF > ~/ARCHLINUX/mirrorlist.hook
[Trigger]
Operation = Upgrade
Type = Package
Target = pacman-mirrorlist

[Action]
Description = Updating pacman mirrorlist and removing mirrorlist.pacnew...
When = PostTransaction
Exec = /bin/sh -c "/usr/local/bin/pacman-mirrorlist"
EOF

sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "mkdir /etc/pacman.d/hooks > /dev/null 2>&1"
sudo mv ~/ARCHLINUX/mirrorlist.hook ~/ARCHLINUX/CHROOT/ARCH_CHROOT/etc/pacman.d/hooks/mirrorlist.hook
echo "installed mirrorlist.hook"

echo "executing pacman-mirrorlist"
sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT /bin/sh -c "/usr/local/bin/pacman-mirrorlist"

sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "pacman -Syu --noconfirm"

sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "echo \"VISUAL=\\\"nano\\\"\" >> /home/$user/.bashrc"
sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "echo export VISUAL >> /home/$user/.bashrc"
sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "echo \"EDITOR=\\\"nano\\\"\" >> /home/$user/.bashrc"
sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "echo export EDITOR >> /home/$user/.bashrc"

sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "echo \"VISUAL=\\\"nano\\\"\" >> /root/.bashrc"
sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "echo export VISUAL >> /root/.bashrc"
sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "echo \"EDITOR=\\\"nano\\\"\" >> /root/.bashrc"
sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "echo export EDITOR >> /root/.bashrc"

sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "echo \"VISUAL=\\\"nano\\\"\" >> /etc/profile"
sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "echo export VISUAL >> /etc/profile"
sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "echo \"EDITOR=\\\"nano\\\"\" >> /etc/profile"
sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "echo export EDITOR >> /etc/profile"

sudo ~/ARCHLINUX/CHROOT/ARCH_CHROOT/bin/arch-chroot ~/ARCHLINUX/CHROOT/ARCH_CHROOT bash -c "sed 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL\n\nDefaults editor=\"\/bin\/nano\", \!env_editor/g' /etc/sudoers > /etc/sudoers.new ; export EDITOR=\"cp /etc/sudoers.new\" ; visudo ; rm /etc/sudoers.new"
