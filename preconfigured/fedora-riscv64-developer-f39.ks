# Kickstart file for Fedora RISC-V (riscv64) Developer F38

#repo --name="koji-override-0" --baseurl=http://fedora.riscv.rocks/repos-dist/f38/latest/riscv64/
repo --name="Openkoji-1" --baseurl=http://openkoji.iscas.ac.cn/kojifiles/repos/f38-build/latest/riscv64/
repo --name="Openkoji-2" --baseurl=http://openkoji.iscas.ac.cn/kojifiles/repos/f38-build-side-42-init-devel/latest/riscv64/
repo --name="Openkoji-3" --baseurl=http://openkoji.iscas.ac.cn/repos/fc38dist/riscv64/
repo --name="Openkoji-4" --baseurl=http://openkoji.iscas.ac.cn/repos/fc38-noarches-repo/riscv64/
repo --name="Openkoji-5" --baseurl=http://openkoji.iscas.ac.cn/pub/temp-f38-repo/riscv64/
repo --name="Openkoji-6" --baseurl=http://openkoji.iscas.ac.cn/pub/temp-python311-repo/riscv64/
repo --name="Openkoji-7" --baseurl=http://openkoji.iscas.ac.cn/pub/temp-python311-repo/riscv64/
repo --name="FedoraRocks-1" --baseurl=http://fedora.riscv.rocks/repos-dist/f38/latest/riscv64/

#install
text
#reboot
lang en_US.UTF-8
keyboard us
# short hostname still allows DHCP to assign domain name
network --bootproto dhcp --device=link --hostname=fedora-riscv --activate
rootpw --plaintext fedora_rocks!
firewall --enabled --ssh
timezone --utc US/Eastern
selinux --enforcing
services --enabled=sshd,NetworkManager,chronyd,haveged --disabled=lm_sensors,libvirtd

zerombr
clearpart --all --initlabel --disklabel=gpt
part /boot/efi --size=100  --fstype=efi
part /boot     --size=1000  --fstype=ext4 --label=boot
part btrfs.007 --size=11240 --fstype=btrfs --grow
btrfs none --label=fedora btrfs.007
btrfs /home --subvol --name=home LABEL=fedora
btrfs /     --subvol --name=root LABEL=fedora
bootloader --location=mbr --timeout=1


# Halt the system once configuration has finished.
poweroff

%packages
@core
@buildsys-build
@hardware-support
@rpm-development-tools
@c-development
@development-tools
@anaconda-tools
@^xfce-desktop-environment
@development-libs
@xfce-apps
@xfce-extra-plugins
@xfce-media
@xfce-office

# This is needed for appliance-tools, as it cannot see what packages are incl. 
# in the @anaconda-tools.
grub2-efi-riscv64

kernel
kernel-core
kernel-devel
kernel-modules
kernel-modules-extra
linux-firmware
opensbi-unstable
uboot-tools
uboot-images-riscv64
# Remove this in %post
dracut-config-generic
-dracut-config-rescue

openssh
openssh-server
glibc-langpack-en
glibc-static
lsof
nano
openrdate
chrony
systemd-udev
vim-minimal
neovim
screen
hostname
bind-utils
htop
tmux
strace
pciutils
nfs-utils
ethtool
rsync
hdparm
git
tig
mercurial
breezy
moreutils
rpmdevtools
fedpkg
mailx
mutt
patchutils
ninja-build
cmake
extra-cmake-modules
elfutils
gdisk
util-linux
parted
fpaste
vim-common
hexedit
xxd
hexyl
poke
poke-devel
poke-vim
poke-emacs
koji-builder
mc
evemu
lftp
mtr
traceroute
wget
curl
aria2
incron
emacs
vim
neofetch
#bash-completion
zsh
tcsh
nvme-cli
pv
dtc
axel
bc
bison
elfutils-devel
flex
m4
man-db
net-tools
openssl-devel
perl-devel
perl-generators
pesign
elinks
lynx
entr
cowsay
ack
the_silver_searcher
tldr
ncdu
colordiff
prettyping
qemu-guest-agent
iptables-services
autoconf
autoconf-archive
automake
gettext
nnn
gdb
libtool
texinfo
policycoreutils
policycoreutils-python-utils
setools-console
coreutils
setroubleshoot-server
audit
selinux-policy
selinux-policy-targeted
execstack
stress-ng
realtime-tests
python3-pyelftools
inxi
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
bdsync
# end of creating disk image packages list
dosfstools
btrfs-progs
compsize
e2fsprogs
f2fs-tools
jfsutils
mtd-utils
ntfsprogs
udftools
xfsprogs
kpartx
guestfs-tools
rpkg
binwalk
bloaty
bpftool
kernel-tools
perf
python3-perf
libgpiod
libgpiod-c++
libgpiod-devel
libgpiod-utils
python3-libgpiod
i2c-tools
i2c-tools-perl
libi2c
libi2c-devel
python3-i2c-tools
spi-tools
# Add gcc packages
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
# end of gcc packages
watchdog

# No longer in @core since 2018-10, but needed for livesys script
initscripts
chkconfig

# Lets resize / on first boot
#dracut-modules-growroot

dnscrypt-proxy
meson
cloud-utils-growpart
iperf3
sysstat
fio
memtester
fuse-sshfs
zstd
xz
NetworkManager-tui
cheat
ddrescue
glances
python3-psutil

# Add dependencies (BR) for kernel, gcc, gdb, binutils, rpm, util-linux, glibc,
# bash and coreutils
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
# end of dependencies (BR)

dos2unix
fwts
acpica-tools
glib
glib2
dkms
expect
openssl
gnutls-utils
iw
info
jq
sysfsutils
golang
golang-bin
bmap-tools
flashrom

glib-devel
glib2-devel
json-c-devel
libbsd-devel
libxcb-devel
zlib-devel
xxhash-devel
xz-devel
mpfr-devel
libmd-devel
libjpeg-devel
libglvnd-devel
libglvnd-core-devel
libgcrypt-devel
libgbm-devel
kmod-devel
keyutils-libs-devel
Judy-devel
eigen3-devel
libaio-devel
xorg-x11-proto-devel
lksctp-tools-devel
brotli-devel
libuv-devel
libnghttp2-devel
libicu-devel
libX11-devel
libXtst-devel
libXt-devel
libXrender-devel
libXrandr-devel
libXi-devel
libXext-devel
libXau-devel
cups-devel
fontconfig-devel
alsa-lib-devel
freetype-devel
libdwarf-devel
gnulib-devel

koji-builder-plugin-rpmautospec
python3-rpmautospec
rpmautospec
rpmautospec-rpm-macros
koji-builder-plugins

rust
cargo

vmtouch

podman
podman-plugins
podmansh
buildah
skopeo
toolbox
crun

libtirpc-devel
%end

%post
# Disable default repositories (not riscv64 in upstream)
dnf config-manager --set-disabled rawhide updates updates-testing fedora fedora-modular fedora-cisco-openh264 updates-modular updates-testing-modular rawhide-modular

dnf -y remove dracut-config-generic

# systemd on no-SMP boots (i.e. single core) sometimes timeout waiting for storage
# devices. After entering emergency prompt all disk are mounted.
# For more information see:
# https://www.suse.com/support/kb/doc/?id=7018491
# https://www.freedesktop.org/software/systemd/man/systemd.mount.html
# https://github.com/systemd/systemd/issues/3446
# We modify /etc/fstab to give more time for device detection (the problematic part)
# and mounting processes. This should help on systems where boot takes longer.
sed -i 's|noatime|noatime,x-systemd.device-timeout=300s,x-systemd.mount-timeout=300s|g' /etc/fstab

# Fedora 31
# https://fedoraproject.org/wiki/Changes/DisableRootPasswordLoginInSshd
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

useradd -c "Fedora RISCV User" riscv
echo fedora_rocks! | passwd --stdin riscv > /dev/null
usermod -aG wheel riscv > /dev/null
usermod -aG mock riscv > /dev/null

exit 0
EOF

chmod 755 /etc/rc.d/init.d/livesys
/sbin/restorecon /etc/rc.d/init.d/livesys
/sbin/chkconfig --add livesys

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

# Disable tmpfs for /tmp
# Most boards don't have a lot of RAM.
systemctl mask tmp.mount

# setup login message
cat << EOF | tee /etc/issue /etc/issue.net
Welcome to the Fedora/RISC-V disk image
https://fedoraproject.org/wiki/Architectures/RISC-V

Build date: $(date --utc)

Kernel \r on an \m (\l)

The root password is 'fedora_rocks!'.
root password logins are disabled in SSH starting Fedora 31.
User 'riscv' with password 'fedora_rocks!' in 'wheel' and 'mock' groups 
is provided.

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

# Remove machine-id on pre generated images
rm -f /etc/machine-id
touch /etc/machine-id

# remove random seed, the newly installed instance should make it's own
rm -f /var/lib/systemd/random-seed

# Note that running rpm recreates the rpm db files which aren't needed or wanted
rm -f /var/lib/rpm/__db*

# go ahead and pre-make the man -k cache (#455968)
/usr/bin/mandb

# make sure there aren't core files lying around
rm -f /core*

releasever=$(rpm --eval '%{fedora}')
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-$releasever-primary
echo "Packages within this disk image"
rpm -qa --qf '%{size}\t%{name}-%{version}-%{release}.%{arch}\n' |sort -rn

%end

%post
cat > /etc/sysconfig/desktop <<EOF
PREFERRED=/usr/bin/startxfce4
DISPLAYMANAGER=/usr/sbin/lightdm
EOF
sed -i 's/^livesys_session=.*/livesys_session="xfce"/' /etc/sysconfig/livesys
%end

# EOF