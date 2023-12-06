#!/bin/bash
echo "$(tput setaf 4)#####################################################################################"
echo "Welcome! This is a docker-based tool for building rpm package and Fedora system image"
echo "                                                                                     "
echo "██████╗ ██╗██╗   ██╗ █████╗ ██╗    ███████╗███████╗██████╗  ██████╗ ██████╗  █████╗  "
echo "██╔══██╗██║██║   ██║██╔══██╗██║    ██╔════╝██╔════╝██╔══██╗██╔═══██╗██╔══██╗██╔══██╗ "
echo "██████╔╝██║██║   ██║███████║██║    █████╗  █████╗  ██║  ██║██║   ██║██████╔╝███████║ "
echo "██╔══██╗██║╚██╗ ██╔╝██╔══██║██║    ██╔══╝  ██╔══╝  ██║  ██║██║   ██║██╔══██╗██╔══██║ "
echo "██║  ██║██║ ╚████╔╝ ██║  ██║██║    ██║     ███████╗██████╔╝╚██████╔╝██║  ██║██║  ██║ "
echo "╚═╝  ╚═╝╚═╝  ╚═══╝  ╚═╝  ╚═╝╚═╝    ╚═╝     ╚══════╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ "
echo "                                                                                     "
echo "#####################################################################################$(tput sgr0)"


########################################################################################################################
# check if the docker engine is available for current user
if ! docker info > /dev/null 2>&1; then
  echo "$(tput setaf 1)ERROR: This script uses docker, and it isn't running - please start docker and try again!$(tput sgr0)"
  exit 1
fi

if [[ $(id -nG | grep -wq "docker"; echo $?) -ne 0 ]]; then
    echo "$(tput setaf 1)ERROR: You do not have the docker access right now, please contact your system admin to obtain!"
    exit 1
fi

########################################################################################################################
# check if network proxy is necessary for current user
if [ "$(ip -4 addr show | grep "wlp")" = "" ]; then
    PROXY_IPV4="127.0.0.1"
else
    PROXY_IPV4=$(ip -4 addr show wlp0s20f3 | grep -Po 'inet \K[\d.]+')
fi
PROXY_PORT="7890"

read -p "$(tput setaf 2)> Do you prefer using Network Proxy? (y/n): $(tput sgr0)" PREFER_PROXY
if [ "$PREFER_PROXY" = "y" -o "$PREFER_PROXY" = "" ]; then
    read -p "$(tput setaf 2)> Please specify your proxy ip addr: (default: $PROXY_IPV4)$(tput sgr0)" CUSTOM_PROXY_IPV4
    read -p "$(tput setaf 2)> Please specify your proxy port: (default: $PROXY_PORT)$(tput sgr0)" CUSTOM_PROXY_PORT
fi
if [ -n "$CUSTOM_PROXY_IPV4" ]; then PROXY_IPV4="$CUSTOM_PROXY_IPV4"; fi
if [ -n "$CUSTOM_PROXY_PORT" ]; then PROXY_PORT="$CUSTOM_PROXY_PORT"; fi

########################################################################################################################

stage1="mock_fedora_builder_stage1"
stage2="mock_fedora_builder_stage2"
stage1_container=${stage1}_container



run_stage1_container() {
    if [ "$PREFER_PROXY" = "y" -o "$PREFER_PROXY" = "" ]; then
        docker run -itd --privileged -P \
               -h rv_builder --name $stage1_container \
               -e "DOCKER_HOST=${PROXY_IPV4}" \
               -e "http_proxy=http://${PROXY_IPV4}:${PROXY_PORT}" \
               -e "https_proxy=https://${PROXY_IPV4}:${PROXY_PORT}" \
               $stage1:latest /bin/bash
    else
        docker run -itd --privileged -P \
               -h rv_builder --name $stage1_container \
               $stage1:latest /bin/bash
    fi
}

MOCK_CONFIG="fedora-38-riscv64.cfg"

if [ "$(docker images | awk '{ print $1 }' | grep "$stage2")" = "" ];then
    printf "$(tput setaf 2)> It seems that the [${stage2}] docker image is not found yet, What's next? $(tput sgr0)\
        \n   1. Load image from a tarball. \
        \n   2. Build it from a former stage [${stage1}].\n"
    read STAGE2_CHOICE
    if [ "$STAGE2_CHOICE" = "1" ]; then
        read -p "$(tput setaf 2)> Please Specify the path of your tarball: $(tput sgr0)" STAGE2_TARBALL_PATH
        docker load < $STAGE2_TARBALL_PATH
        run_stage1_container
    else
        if [ "$(docker images | awk '{ print $1 }' | grep "$stage1")" = "" ];then
            printf "$(tput setaf 2)> It seems that the [${stage1}] docker image is not found yet, What's next? $(tput sgr0)\
                   \n   1. Load image from a tarball. \
                   \n   2. Build it from scratch. \n"
            read STAGE1_CHOICE
            if [ $STAGE1_CHOICE = '1' ]; then
                read -p "$(tput setaf 2)> Please Specify the path of your tarball: $(tput sgr0)" STAGE1_TARBALL_PATH
                docker load < $STAGE1_TARBALL_PATH
            else
                if [ "$(docker images | awk '{ print $1 }' | grep "fedora")" = "" ]; then docker pull fedora:latest; fi
                if [ "$PREFER_PROXY" = "y" -o "$PREFER_PROXY" = "" ]; then
                    docker build -t $stage1 . --build-arg proxy_ipv4=$PROXY_IPV4 --build-arg proxy_port=$PROXY_PORT
                else
                    docker build -t $stage1 .
                fi
                echo "INFO: $stage1 image created. now runing its instance under privilege mode."
                echo "INFO: create and run $stage1_container ..."
                run_stage1_container
            fi
        else
            if [ "$(docker ps -a -q -f name=$stage1_container)" ]; then
                if [ "$(docker inspect -f {{.State.Running}} $stage1_container 2>/dev/null)" = "true" ]; then
                    echo "INFO: docker $stage1_container is already running."
                else
                    echo "INFO: starting $stage1_container ..."
                    docker start $stage1_container
                fi
            else
                echo "INFO: create and run $stage1_container ..."
                run_stage1_container
            fi
        fi
    fi

    if [ ! -f "./$MOCK_CONFIG" ]; then
        echo "$(tput setaf 1)ERROR: mock configuration file is missing. stop.$(tput sgr0)"
        exit 1
    fi
    docker cp $MOCK_CONFIG $stage1_container:/home/riscv/
    docker exec $stage1_container bash -c \
        "
        unset http_proxy https_proxy && \
        cd /home/riscv && \
        sudo chown riscv:riscv ./$MOCK_CONFIG && \
        mkdir -p ./mock_root_dir ./mock_result_dir && \
        mock -r ./$MOCK_CONFIG --init --forcearch=riscv64
            --rootdir /home/riscv/mock_root_dir --resultdir /home/riscv/mock_result_dir
        "
    if [ "$PREFER_PROXY" = "y" -o "$PREFER_PROXY" = "" ]; then
    docker exec $stage1_container bash -c \
        "
        cd /home/riscv && \
        mock -r ./$MOCK_CONFIG --isolation=simple --enable-network \
            --rootdir /home/riscv/mock_root_dir --resultdir /home/riscv/mock_result_dir \
            --chroot \"echo \'proxy=http://${PROXY_IPV4}:${PROXY_PORT}\' >> /etc/dnf/dnf.conf \"
        "
    fi
    docker exec $stage1_container bash -c \
        "
        cd /home/riscv && \
        mock -r ./$MOCK_CONFIG --rootdir /home/riscv/mock_root_dir --resultdir /home/riscv/mock_result_dir \
            --install anaconda lorax git vim pykickstart dnf hfsplus-tools lorax-lmc-novirt wget \
            appliance-tools livecd-tools
        "
    docker commit -p $stage1_container $stage2
fi

docker stop $stage1_container

printf "$(tput setaf 2)> What is your building target?$(tput sgr0) \
        \n  1. RPM Packages. \
        \n  2. System Images. \n"
read BUILDING_TARGET

if [ "$BUILDING_TARGET" = "1" ]; then
    echo "" #TODO
else
    SELECTED_KICKSTART_NAME=""
    echo "$(tput setaf 2)> Now we handle the kickstart file, which would you like?$(tput sgr0)"
    echo "  1. preconfigured. (We will use the locally stored kickstart file example)"
    echo "  2. assembled. (We will go through some basic options to assemble a complete kickstart file)"
    echo "  3. customized. (Please tell me the path to your personal kickstart file or network address)"
    read KICKSTART_STYLE
    case $KICKSTART_STYLE in
        1)
            if [ ! -d "./preconfigured" ]; then
                echo "ERROR: no preconfigured directory found."
                exit 1
            fi
            ks_files=()
            cd ./preconfigured
            for file in *.ks; do
                [ -e "$file" ] || continue
                ks_files+=("$file")
            done
            cd ..
            echo "$(tput setaf 2)> Choose a preconfigured kickstart file as you image blueprint:$(tput sgr0)"
            cd ./preconfigured

            count=0
            for file in *.ks
            do
            ((count++))
            echo "  $count: $file"
            done

            read -s choice
            if [[ $choice -ge 1 && $choice -le $count ]];then
                TARGET_KICKSTART_FILE=$(realpath *.ks | head -n $choice | tail -n 1)
            else
                echo "ERROR: wrong selection!"
                exit 1
            fi
            cd ..
        ;;
        2)
            if [ ! -d "./fedora-kickstarts" ]; then
                git clone https://pagure.io/fedora-kickstarts.git --quiet
            fi

            sed -i '/%include fedora-repo\.ks/d' ./fedora-kickstarts/fedora-live-base.ks

            if [ -d "./addon" ]; then
                for file in ./addon/*ks; do
                    cp $file ./fedora-kickstarts/
                done
            fi


            echo "$(tput setaf 2)> Now I'll give you some options to compose a system image configuration that you like.$(tput sgr0)"
            #######################################################################################################
            echo "$(tput setaf 2)> Firstly, give me the name of your favorite ks file, which will be assembled from the following options$(tput sgr0)"
            read SELECTED_KICKSTART_NAME
            if [ -n $SELECTED_KICKSTART_NAME ]; then
                TARGET_KICKSTART_FILE=./fedora-kickstarts/${SELECTED_KICKSTART_NAME}.ks
                rm -rf $TARGET_KICKSTART_FILE
                touch $TARGET_KICKSTART_FILE
                if [ -f "./fedora-kickstarts/fedora-repo-ch.ks" ]; then
                    echo "%include fedora-repo-ch.ks" >> $TARGET_KICKSTART_FILE
                fi
                cat >> $TARGET_KICKSTART_FILE <<-WEOF
                %include fedora-live-base.ks
                %include fedora-workstation-common.ks
				WEOF

                command -v ksflatten >/dev/null 2>&1 || pip install pykickstart
                ksflatten -c $TARGET_KICKSTART_FILE -o $TARGET_KICKSTART_FILE
                sed -i '/^\(lang\|keyboard\|network\|rootpw\|firewall\|timezone\|selinux\|services\)/d' $TARGET_KICKSTART_FILE

                cat >> $TARGET_KICKSTART_FILE <<-WEOF
                text
                #reboot
                lang en_US.UTF-8
                keyboard us
                # short hostname still allows DHCP to assign domain name
                network --bootproto dhcp --device=link --hostname=fedora-riscv --activate
                rootpw --plaintext fedora_rocks!
                firewall --enabled --ssh
                timezone --utc Asia/Shanghai
                selinux --disabled
                services --enabled=sshd,NetworkManager,chronyd,haveged,lightdm --disabled=lm_sensors,libvirtd
                # Halt the system once configuration has finished.
                poweroff

                %packages
                @hardware-support
                @buildsys-build
                shadow-utils # for useradd action
                kernel-core
                kernel-devel
                openssh
                openssh-server
                # No longer in @core since 2018-10, but needed for livesys script
                initscripts
                chkconfig
                # Below packages are needed for creating disk images via koji-builder
                livecd-tools
                python-imgcreate-sysdeps
                python3-imgcreate
                python3-pyparted
                isomd5sum
                python3-isomd5sum
                pykickstart
                python3-kickstart
                python3-ordered-set
                appliance-tools
                pycdio
                qemu-img
                nbdkit
                nbd
                # end of creating disk image packages list
                %end

                %post

                dnf config-manager --set-disabled rawhide updates updates-testing fedora fedora-modular fedora-cisco-openh264 updates-modular updates-testing-modular rawhide-modular
                dnf -y remove dracut-config-generic

                # Create Fedora RISC-V repo
                cat << EOF > /etc/yum.repos.d/fedora-riscv.repo
                [fedora-riscv]
                name=Fedora RISC-V
                baseurl=http://fedora.riscv.rocks/repos-dist/f38/latest/riscv64/
                #baseurl=https://dl.fedoraproject.org/pub/alt/risc-v/repo/fedora/f38/latest/riscv64/
                #baseurl=https://mirror.math.princeton.edu/pub/alt/risc-v/repo/fedora/f38/latest/riscv64/
                enabled=1
                gpgcheck=0

                [fedora-riscv-debuginfo]
                name=Fedora RISC-V - Debug
                baseurl=http://fedora.riscv.rocks/repos-dist/f38/latest/riscv64/debug/
                #baseurl=https://dl.fedoraproject.org/pub/alt/risc-v/repo/fedora/f38/latest/riscv64/debug/
                #baseurl=https://mirror.math.princeton.edu/pub/alt/risc-v/repo/fedora/f38/latest/riscv64/debug/
                enabled=0
                gpgcheck=0

                [fedora-riscv-source]
                name=Fedora RISC-V - Source
                baseurl=http://fedora.riscv.rocks/repos-dist/f38/latest/src/
                #baseurl=https://dl.fedoraproject.org/pub/alt/risc-v/repo/fedora/f38/latest/src/
                #baseurl=https://mirror.math.princeton.edu/pub/alt/risc-v/repo/fedora/f38/latest/src/
                enabled=0
                gpgcheck=0
                EOF

                # Create Fedora RISC-V Koji repo
                cat << EOF > /etc/yum.repos.d/fedora-riscv-koji.repo
                [fedora-riscv-koji]
                name=Fedora RISC-V Koji
                baseurl=http://fedora.riscv.rocks/repos/f38-build/latest/riscv64/
                enabled=0
                gpgcheck=0
                EOF

                # systemd starts serial consoles on /dev/ttyS0 and /dev/hvc0.  The
                # only problem is they are the same serial console.  Mask one.
                systemctl mask serial-getty@hvc0.service

                releasever=$(rpm --eval '%{fedora}')
                rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-$releasever-primary

                # systemd on no-SMP boots (i.e. single core) sometimes timeout waiting for storage
                # devices. After entering emergency prompt all disk are mounted.
                # For more information see:
                # https://www.suse.com/support/kb/doc/?id=7018491
                # https://www.freedesktop.org/software/systemd/man/systemd.mount.html
                # https://github.com/systemd/systemd/issues/3446
                # We modify /etc/fstab to give more time for device detection (the problematic part)
                # and mounting processes. This should help on systems where boot takes longer.
                sed -i 's|noatime|noatime,x-systemd.device-timeout=300s,x-systemd.mount-timeout=300s|g' /etc/fstab

                # remove unnecessary entry in /etc/fstab

                sed -i '/swap/d' /etc/fstab
                sed -i '/efi/d' /etc/fstab

                DTB_PATH=$(ls /boot | grep dtb)
                wget https://github.com/starfive-tech/VisionFive2/releases/download/VF2_v3.8.2/jh7110-visionfive-v2.dtb -P /boot/\${DTB_PATH}/starfive

                %end
				WEOF
            fi
            #######################################################################################################
            printf "$(tput setaf 2)> Please set the login user and passwd with the format [user:passwd]\n$(tput sgr0)"
            read LOGIN_USER_PASSWD
            if [ -n $LOGIN_USER_PASSWD ]; then
                INPUT_USER="$(echo $LOGIN_USER_PASSWD | cut -d ":" -f 1)"
                INPUT_PASSWD="$(echo $LOGIN_USER_PASSWD | cut -d ":" -f 2)"
                cat >> $TARGET_KICKSTART_FILE <<-WEOF
                %post
                cat > /etc/rc.d/init.d/livesys << EOF
                #!/bin/bash
                #
                # live: Init script for live image
                #
                # chkconfig: 345 00 99
                # description: Init script for live image.
                ### BEGIN INIT INFO
                # X-Start-Before: display-manager chronyd
                ### END INIT INFO

                . /etc/rc.d/init.d/functions

                useradd -c "Fedora RISCV User" $INPUT_USER
                echo $INPUT_PASSWD | passwd --stdin $INPUT_USER > /dev/null

                exit 0
                EOF

                chmod 755 /etc/rc.d/init.d/livesys
                /sbin/restorecon /etc/rc.d/init.d/livesys
                /sbin/chkconfig --add livesys

                # setup login message
                cat << EOF | tee /etc/issue /etc/issue.net
                Welcome to the Fedora/RISC-V disk image
                https://fedoraproject.org/wiki/Architectures/RISC-V

                Build date: $(date --utc)

                Kernel \r on an \m (\l)

                The root password is 'fedora_rocks!'.
                root password logins are disabled in SSH starting Fedora 38.
                User '$INPUT_USER' with password '$INPUT_PASSWD' is provided.

                To install new packages use 'dnf install ...'

                To upgrade disk image use 'dnf upgrade --best'

                If DNS isn’t working, try editing ‘/etc/yum.repos.d/fedora-riscv.repo’.

                For updates and latest information read:
                https://fedoraproject.org/wiki/Architectures/RISC-V

                Fedora/RISC-V
                -------------
                Koji:               http://fedora.riscv.rocks/koji/
                SCM:                http://fedora.riscv.rocks:3000/
                Distribution rep.:  http://fedora.riscv.rocks/repos-dist/
                Koji internal rep.: http://fedora.riscv.rocks/repos/
                EOF
                %end
				WEOF
            fi
            #######################################################################################################
            printf "$(tput setaf 2)> Do you need a desktop environment, and if so, which one below is your favorite? \
                    \n  (You could have more than one of them with typing like '123')$(tput sgr0)\n"
            echo "  0. DO NOT NEED a desktop"
            echo "  1. xfce"
            echo "  2. kde"
            echo "  3. gnome"
            echo "  4. lxde"
            echo "  5. lxqt"
            read TARGET_DESKTOP_TYPE

            if [[ $TARGET_DESKTOP_TYPE == *1* ]]; then
                cat >> $TARGET_KICKSTART_FILE <<-WEOF
                %include fedora-xfce-common.ks
                %packages
                @base-x
                %end
                %post
                cat > /etc/sysconfig/desktop <<EOF
                PREFERRED=/usr/bin/startxfce4
                DISPLAYMANAGER=/usr/sbin/lightdm
                EOF
                sed -i 's/^livesys_session=.*/livesys_session="xfce"/' /etc/sysconfig/livesys
                %end
				WEOF
            fi

            if [[ $TARGET_DESKTOP_TYPE == *2* ]]; then
                cat >> $TARGET_KICKSTART_FILE <<-WEOF
                %packages
                @^kde-desktop-environment
                @firefox
                @kde-apps
                @kde-media
                @kde-pim
                @libreoffice
                libreoffice-draw
                libreoffice-math
                fedora-release-kde
                -@admin-tools
                -tracker-miners
                -tracker
                kde-l10n
                -ktorrent
                -digikam
                -kipi-plugins
                -krusader
                -k3b
                %end
                %post
                cat > /root/.gtkrc-2.0 << EOF
                include "/usr/share/themes/Adwaita/gtk-2.0/gtkrc"
                include "/etc/gtk-2.0/gtkrc"
                gtk-theme-name="Adwaita"
                EOF
                mkdir -p /root/.config/gtk-3.0
                cat > /root/.config/gtk-3.0/settings.ini << EOF
                [Settings]
                gtk-theme-name = Adwaita
                EOF
                sed -i 's/^livesys_session=.*/livesys_session="kde"/' /etc/sysconfig/livesys
                %end
				WEOF
            fi

            if [[ $TARGET_DESKTOP_TYPE == *3* ]]; then
                cat >> $TARGET_KICKSTART_FILE <<-WEOF
                %packages
                @gnome-desktop
                @base-x
                gnome-terminal
                gdm
                nautilus
                %end
                %post
                sed -i 's/^livesys_session=.*/livesys_session="kde"/' /etc/sysconfig/livesys
                %end
				WEOF
            fi

            if [[ $TARGET_DESKTOP_TYPE == *4* ]]; then
                cat >> $TARGET_KICKSTART_FILE <<-WEOF
                %packages
                @^lxde-desktop-environment
                @lxde-apps
                @lxde-media
                @lxde-office
                -fprintd-pam
                -polkit-gnome
                -polkit-kde
                notification-daemon
                -xfce4-notifyd
                metacity
                -@admin-tools
                -autofs
                -acpid
                -gimp-help
                -desktop-backgrounds-basic
                -foomatic-db-ppds
                -foomatic
                -stix-fonts
                -default-fonts-core-math
                -ibus-typing-booster
                -xscreensaver-extras
                -system-config-network
                -system-config-rootpassword
                -policycoreutils-gui
                -gnome-disk-utility
                %end
                %post
                cat > /etc/sysconfig/desktop <<EOF
                PREFERRED=/usr/bin/startlxde
                DISPLAYMANAGER=/usr/sbin/lxdm
                EOF
                sed -i 's/^livesys_session=.*/livesys_session="lxde"/' /etc/sysconfig/livesys
                %end
				WEOF
            fi

            if [[ $TARGET_DESKTOP_TYPE == *5* ]]; then
                cat >> $TARGET_KICKSTART_FILE <<-WEOF
                %packages
                @^lxqt-desktop-environment
                @lxqt-apps
                @lxqt-media
                gnome-keyring
                @lxqt-l10n
                lximage-qt-l10n
                obconf-qt-l10n
                pavucontrol-qt-l10n
                gstreamer1-plugin-mpg123
                enki
                wqy-microhei-fonts
                -naver-nanum-gothic-fonts
                -vlgothic-fonts
                -adobe-source-han-sans-cn-fonts
                -adobe-source-han-sans-tw-fonts
                -pt-sans-fonts
                -@input-methods
                -@admin-tools
                -scim*
                -m17n*
                -iok
                storaged
                dracut-config-generic
                %end
                %post
                sed -i 's/^livesys_session=.*/livesys_session="lxqt"/' /etc/sysconfig/livesys
                %end
				WEOF
            fi
            #######################################################################################################
            echo "$(tput setaf 2)> Do you need to pre-install the gcc toolchain? (y/n)$(tput sgr0)"
            read NEED_GCC_TOOL
            if [ "$NEED_GCC_TOOL" = "y" -o  "$NEED_GCC_TOOL" = "" ]; then
                cat >> $TARGET_KICKSTART_FILE <<-WEOF
                %packages
                cpp
                gcc
                gcc-c++
                gcc-gdb-plugin
                gcc-gfortran
                gcc-plugin-devel
                libatomic
                libatomic-static
                libgcc
                libgfortran
                libgfortran-static
                libgomp
                libstdc++
                libstdc++-devel
                libstdc++-static
                pax-utils
                gcc-gnat
                libgnat
                libgnat-devel
                libgnat-static
                usbutils
                haveged
                %end
				WEOF
            fi
            #######################################################################################################
            printf "$(tput setaf 2)> Do you need a development environment for programming languages pre-installed in the system image?  \
                    \n  (Warning: this can significantly increase the size of the package)$(tput sgr0)\n"
            echo "  0. DO NOT NEED Any of them"
            echo "  1. C/C++"
            echo "  2. Java"
            echo "  3. go"
            echo "  4. Rust"
            read TARGET_DEVELOP_TYPE
            if [[ $TARGET_DEVELOP_TYPE == *1* ]]; then
                cat >> $TARGET_KICKSTART_FILE <<-WEOF
                %packages
                @c-development
                @development-libs
                @development-tools
                glibc-devel
                cpp
                %end
				WEOF
            fi

            if [[ $TARGET_DEVELOP_TYPE == *2* ]]; then
                cat >> $TARGET_KICKSTART_FILE <<-WEOF
                %packages
                java-devel
                java-openjdk-headless
                java-openjdk
                %end
				WEOF
            fi

            if [[ $TARGET_DEVELOP_TYPE == *3* ]]; then
                cat >> $TARGET_KICKSTART_FILE <<-WEOF
                %packages
                golang
                %end
				WEOF
            fi

            if [[ $TARGET_DEVELOP_TYPE == *4* ]]; then
                cat >> $TARGET_KICKSTART_FILE <<-WEOF
                %packages
                rust
                cargo
                %end
				WEOF
            fi
            #######################################################################################################
            echo "$(tput setaf 2)> Do you need to pre-install some common development libraries? (y/n)$(tput sgr0)"
            read NEED_DEV_LIBS
            if [ $NEED_DEV_LIBS = "y" -o $NEED_DEV_LIBS = "" ]; then
                cat >> $TARGET_KICKSTART_FILE <<-WEOF
                %packages
                audit-libs-devel
                bzip2-devel
                dblatex
                dbus-devel
                dejagnu
                docbook5-style-xsl
                dwarves
                expat-devel
                fakechroot
                file-devel
                gd-devel
                gettext-devel
                glibc-all-langpacks
                ima-evm-utils-devel
                isl-devel
                libacl-devel
                libarchive-devel
                libattr-devel
                libbabeltrace-devel
                libcap-devel
                libcap-ng-devel
                libdb-devel
                libpng-devel
                libselinux-devel
                libuser-devel
                libutempter-devel
                libzstd-devel
                lua-devel
                ncurses-devel
                pam-devel
                pcre2-devel
                perl
                popt-devel
                python3-devel
                python3-langtable
                python3-sphinx
                readline-devel
                rpm-devel
                sharutils
                source-highlight-devel
                systemd-devel
                texinfo-tex
                texlive-collection-latex
                texlive-collection-latexrecommended
                zlib-static
                %end
				WEOF
            fi
            sed -i 's/^[ \t]*//' $TARGET_KICKSTART_FILE

            command -v ksflatten >/dev/null 2>&1 || pip install pykickstart
            ksflatten -c $TARGET_KICKSTART_FILE -o $TARGET_KICKSTART_FILE
            #######################################################################################################
            echo "$(tput setaf 2)> Which Type of Bootloader do you prefer?$(tput sgr0)"
            echo "  0. Legacy BIOS with U-boot"
            echo "  1. UEFI BIOS"
            echo "  2. Both Legacy and UEFI are needed"
            read TARGET_BOOTLOADER_TYPE
            sed -i '/^\(zerombr\|clearpart\|part\|btrfs\|bootloader\)/d' $TARGET_KICKSTART_FILE
            if [ $TARGET_BOOTLOADER_TYPE = "0" ]; then
                cat >> $TARGET_KICKSTART_FILE <<-WEOF
                zerombr
                clearpart --all --initlabel --disklabel=gpt
                part /boot --size=512 --fstype vfat --asprimary
                part / --fstype="ext4" --size=12288
                bootloader --location=none --extlinux --append="root=/dev/mmcblk1p4 rw console=tty0 console=ttyS0,115200 earlycon rootwait selinux=0"
                %packages
                extlinux-bootloader
                linux-firmware
                uboot-tools
                uboot-images-riscv64
                dracut-config-generic
                -dracut-config-rescue
                %end
                %post
                sed -i \
                -e 's/^ui/# ui/g'	\
                -e 's/^menu autoboot/# menu autoboot/g'	\
                -e 's/^menu hidden/# menu hidden/g'	\
                -e 's/^totaltimeout/# totaltimeout/g'	\
                /boot/extlinux/extlinux.conf
                %end
				WEOF
            fi

            if [ $TARGET_BOOTLOADER_TYPE = "1" ]; then
                cat >> $TARGET_KICKSTART_FILE <<-WEOF

                zerombr
                clearpart --all --initlabel --disklabel=gpt
                part /boot/efi --fstype=vfat --size=100
                part / --fstype=ext4 --size=12288 --label=rootfs --grow
                bootloader --location=none --timeout=1 --append="root=/dev/mmcblk1p4 rw console=tty0 console=ttyS0,115200 earlycon rootwait selinux=0"

                %packages
                @core
                efibootmgr

                grub2
                # grub2-common
                grub2-efi-riscv64
                # grub2-efi-riscv64-cdboot
                grub2-efi-riscv64-modules
                # grub2-pc-modules
                # grub2-tools
                # grub2-tools-extra
                # grub2-tools-minimal

                opensbi-unstable
                linux-firmware
                uboot-tools
                uboot-images-riscv64
                -dracut-config-rescue
                dracut-config-generic
                %end
				WEOF
            fi

            if [ $TARGET_BOOTLOADER_TYPE = "2" ]; then
                cat >> $TARGET_KICKSTART_FILE <<-WEOF
                clearpart --all --initlabel --disklabel=gpt
                part prepboot  --size=4    --fstype=prepboot
                part biosboot  --size=1    --fstype=biosboot
                part /boot/efi --size=100  --fstype=efi
                part /boot     --size=1000  --fstype=ext4 --label=boot
                part btrfs.007 --size=2000 --fstype=btrfs --grow
                btrfs none --label=fedora btrfs.007
                btrfs /home --subvol --name=home LABEL=fedora
                btrfs /     --subvol --name=root LABEL=fedora
                bootloader --location=mbr --timeout=1 --append="console=tty1 console=ttyS0,115200 debug rootwait earlycon=sbi"
				WEOF
            fi

            echo "$(tput setaf 2)> Which version of Fedora Image Type do you prefer?$(tput sgr0)"
            echo "  0. Live Image"
            echo "  1. Bootable Image"
            read TARGET_IMAGE_TYPE

            sed -i 's/^[ \t]*//' $TARGET_KICKSTART_FILE
            ksflatten -c $TARGET_KICKSTART_FILE -o $TARGET_KICKSTART_FILE
            cp $TARGET_KICKSTART_FILE ./preconfigured
        ;;
        3) echo "customized"
        ;;
        *) echo "error"
        ;;
    esac

    if [ "$KICKSTART_STYLE" = "1" ]; then SELECTED_KICKSTART_NAME=$(basename -s .ks $TARGET_KICKSTART_FILE); fi
    STAGE2_CONTAINER="${stage2}_container_${SELECTED_KICKSTART_NAME}"
    if [ "$(docker ps -a -q -f name=$STAGE2_CONTAINER)" ]; then
        if [ "$(docker inspect -f {{.State.Running}} $STAGE2_CONTAINER 2>/dev/null)" = "true" ]; then
            echo "INFO: docker $STAGE2_CONTAINER is already running."
        else
            echo "INFO: starting $STAGE2_CONTAINER ..."
            docker start $STAGE2_CONTAINER
    fi
    else
        echo "INFO: create and run $STAGE2_CONTAINER ..."
        if [ "$PREFER_PROXY" = "y" -o "$PREFER_PROXY" = "" ]; then
            docker run -itd --privileged -P \
                -h rv_builder --name $STAGE2_CONTAINER \
                -e "DOCKER_HOST=${PROXY_IPV4}" \
                -e "http_proxy=http://${PROXY_IPV4}:${PROXY_PORT}" \
                -e "https_proxy=https://${PROXY_IPV4}:${PROXY_PORT}" \
                $stage2:latest /bin/bash
        else
            docker run -itd --privileged -P \
                -h rv_builder --name $STAGE2_CONTAINER \
                $stage2:latest /bin/bash
        fi
    fi
    docker cp $TARGET_KICKSTART_FILE $STAGE2_CONTAINER:/home/riscv/

    docker exec $STAGE2_CONTAINER bash -c \
        "
        cd /home/riscv && \
        sudo chown riscv:riscv ./${SELECTED_KICKSTART_NAME}.ks && \
        mock -r ./$MOCK_CONFIG --isolation=simple --enable-network \
            --rootdir /home/riscv/mock_root_dir --resultdir /home/riscv/mock_result_dir \
            --copyin ./${SELECTED_KICKSTART_NAME}.ks /builddir && \
        mock -r ./$MOCK_CONFIG --isolation=simple --enable-network \
            --rootdir /home/riscv/mock_root_dir --resultdir /home/riscv/mock_result_dir \
            --chroot \
            \"
                sed -i '/MountError(umount_fail_fmt/d' /usr/lib/python3.11/site-packages/imgcreate/fs.py && \
                sed -i 's/grub2-efi-aa64/grub2-efi-riscv64/g' /usr/lib/python3.11/site-packages/appcreate/appliance.py && \
                cd /builddir && appliance-creator -c ./${SELECTED_KICKSTART_NAME}.ks --cache ./cache -o ./images --format raw \
                    --name $SELECTED_KICKSTART_NAME --vcpu=20 --vmem=10240 --version f38 --release \`date +%Y%m%d-%H%M%S\`
            \"
        "
    mkdir -p output

    if [ "$TARGET_IMAGE_TYPE" = "1" ]; then
        docker exec $STAGE2_CONTAINER bash -c \
            "
            cd /home/riscv/mock_root_dir/images && \
            unxz ${SELECTED_KICKSTART_NAME}-sda.raw.xz && \
            wget https://github.com/starfive-tech/VisionFive2/releases/download/VF2_v3.8.2/u-boot-spl.bin.normal.out && \
            wget https://github.com/starfive-tech/VisionFive2/releases/download/VF2_v3.8.2/visionfive2_fw_payload.img && \
            dd if=/dev/zero of=${SELECTED_KICKSTART_NAME}-vf2-bootable-sda.img bs=1M count=10240 && \
            sudo sgdisk -g --clear --set-alignment=1 																				\
	            --new=1:4096:+2M: 		--change-name=1:'spl' 				--typecode=1:2E54B353-1271-4842-806F-E436D6AF6985 		\
	            --new=2:8192:+4M: 		--change-name=2:'opensbi-uboot' 	--typecode=2:5b193300-fc78-40cd-8002-e86c45580b47 		\
	            --new=3:16384:+100M: 	--change-name=3:'efi'		   		--typecode=3:C12A7328-F81F-11D2-BA4B-00A0C93EC93B  		\
	            --new=4:221184:-0   	--change-name=4:'rootfs'       		--typecode=4:0FC63DAF-8483-4772-8E79-3D69D8477DE4 		\
	            ${SELECTED_KICKSTART_NAME}-vf2-bootable-sda.img && \
            BOOTABLE_DEV_NUM=$(echo $(sudo losetup --partscan --find --show ${SELECTED_KICKSTART_NAME}-vf2-bootable-sda.img) | grep -oP '/dev/loop\K\d+') && \
            sudo mkfs.vfat /dev/loop\${BOOTABLE_DEV_NUM}p3 && \
            sudo mkfs.ext4 /dev/loop\${BOOTABLE_DEV_NUM}p4 && \
            sudo fatlabel /dev/loop\${BOOTABLE_DEV_NUM}p3 BOOT && \
            sudo e2label /dev/loop$\{BOOTABLE_DEV_NUM}p4 ROOTFS && \
            RAW_DEV_NUM=\$(echo \$(sudo losetup --partscan --find --show ${SELECTED_KICKSTART_NAME}-sda.raw) | grep -oP '/dev/loop\K\d+') && \
            sudo dd if=u-boot-spl.bin.normal.out of=/dev/loop\${BOOTABLE_DEV_NUM}p1 bs=64k iflag=fullblock oflag=direct conv=fsync status=progress && \
            sudo dd if=visionfive2_fw_payload.img of=/dev/loop\${BOOTABLE_DEV_NUM}p2 bs=64k iflag=fullblock oflag=direct conv=fsync status=progress && \
            sudo dd if=/dev/loop\${RAW_DEV_NUM}p1 of=/dev/loop\${BOOTABLE_DEV_NUM}p3 bs=64k iflag=fullblock oflag=direct conv=fsync status=progress && \
            sudo dd if=/dev/loop\${RAW_DEV_NUM}p2 of=/dev/loop\${BOOTABLE_DEV_NUM}p4 bs=64k iflag=fullblock oflag=direct conv=fsync status=progress && \
            sudo losetup -d /dev/loop\${BOOTABLE_DEV_NUM} && \
            sudo losetup -d /dev/loop\${RAW_DEV_NUM}
            "
        docker cp $STAGE2_CONTAINER:/home/riscv/mock_root_dir/builddir/images/$SELECTED_KICKSTART_NAME/${SELECTED_KICKSTART_NAME}-vf2-bootable-sda.img ./output
    else
        docker cp $STAGE2_CONTAINER:/home/riscv/mock_root_dir/builddir/images/$SELECTED_KICKSTART_NAME/${SELECTED_KICKSTART_NAME}-sda.raw.xz ./output
    fi
    docker cp $STAGE2_CONTAINER:/home/riscv/mock_result_dir/root.log ./output
    docker stop $STAGE2_CONTAINER
fi