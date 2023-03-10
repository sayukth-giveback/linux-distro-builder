echo "##### installing requrements"
# adding symbolic link | fixes: ERROR: /bin/sh does not point to bash
ln -sf bash /bin/sh > /dev/null 2>&1
# Binutils, gcc , g++, xz, make, patch
apt-get -y update 
apt-get install -y --no-install-recommends build-essential
apt-get install -y libncurses5-dev perl wget ca-certificates
apt-get install -y flex
apt-get install -y texinfo
apt-get install -y libelf-dev
apt-get install -y libssl-dev

# Configuring the Environment

# turn on Bash hash functions
set +h
# Make sure that newly created files/directories are writable only by the owner
umask 022

export LJOS=~/lj-os
mkdir -pv ${LJOS}
export LC_ALL=POSIX
export PATH=${LJOS}/cross-tools/bin:/bin:/usr/bin

# directory tree

mkdir -pv ${LJOS}/{bin,boot{,grub}/grub,dev,{etc/,}opt,home,lib/{firmware,modules},lib64,mnt}
mkdir -pv ${LJOS}/{proc,media/{floppy,cdrom},sbin,srv,sys}
mkdir -pv ${LJOS}/var/{lock,log,mail,run,spool}
mkdir -pv ${LJOS}/var/{opt,cache,lib/{misc,locate},local}

# install:  copies files (often just compiled) into destination locations you choose
install -dv -m 0750 ${LJOS}/root
install -dv -m 1777 ${LJOS}{/var,}/tmp
install -dv ${LJOS}/etc/init.d

mkdir -pv ${LJOS}/usr/{,local/}{bin,include,lib{,64},sbin,src}
mkdir -pv ${LJOS}/usr/{,local/}share/{doc,info,locale,man}
mkdir -pv ${LJOS}/usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -pv ${LJOS}/usr/{,local/}share/man/man{1,2,3,4,5,6,7,8}
for dir in ${LJOS}/usr{,/local}; do
    ln -sv share/{man,doc,info} ${dir}
done


# Create the directory for a cross-compilation toolchain
install -dv ${LJOS}/cross-tools{,/bin}
ln -svf ../proc/mounts ${LJOS}/etc/mtab


# create the /etc/passwd
cat > ${LJOS}/etc/passwd << "EOF"
root::0:0:root:/root:/bin/ash
EOF


# Create the /etc/group file
cat > ${LJOS}/etc/group << "EOF"
root:x:0:
bin:x:1:
sys:x:2:
kmem:x:3:
tty:x:4:
daemon:x:6:
disk:x:8:
dialout:x:10:
video:x:12:
utmp:x:13:
usb:x:14:
EOF


# create /etc/fstab
cat > ${LJOS}/etc/fstab << "EOF"
# file system  mount-point  type   options          dump  fsck
#                                                         order

rootfs          /               auto    defaults        1      1
proc            /proc           proc    defaults        0      0
sysfs           /sys            sysfs   defaults        0      0
devpts          /dev/pts        devpts  gid=4,mode=620  0      0
tmpfs           /dev/shm        tmpfs   defaults        0      0
EOF


# /etc/profile
cat > ${LJOS}/etc/profile << "EOF"
export PATH=/bin:/usr/bin

if [ `id -u` -eq 0 ] ; then
        PATH=/bin:/sbin:/usr/bin:/usr/sbin
        unset HISTFILE
fi


# Set up some environment variables.
export USER=`id -un`
export LOGNAME=$USER
export HOSTNAME=`/bin/hostname`
export HISTSIZE=1000
export HISTFILESIZE=1000
export PAGER='/bin/more '
export EDITOR='/bin/vi'
EOF


# machine's hostname
echo "ljos" > ${LJOS}/etc/HOSTNAME


# /etc/issue (displayed prominently at the login prompt)
cat > ${LJOS}/etc/issue<< "EOF"
Linux OS DIY minimal 
Kernel \r on an \m

EOF


# use the basic init process provided by BusyBox
# define an /etc/inittab file
cat > ${LJOS}/etc/inittab<< "EOF"
::sysinit:/etc/rc.d/startup

tty1::respawn:/sbin/getty 38400 tty1
tty2::respawn:/sbin/getty 38400 tty2
tty3::respawn:/sbin/getty 38400 tty3
tty4::respawn:/sbin/getty 38400 tty4
tty5::respawn:/sbin/getty 38400 tty5
tty6::respawn:/sbin/getty 38400 tty6

::shutdown:/etc/rc.d/shutdown
::ctrlaltdel:/sbin/reboot
EOF



# use mdev instead of udev (as a result of leveraging BusyBox to simplify some of the most common Linux system functionality)
cat > ${LJOS}/etc/mdev.conf<< "EOF"
# Devices:
# Syntax: %s %d:%d %s
# devices user:group mode

# null does already exist; therefore ownership has to
# be changed with command
null    root:root 0666  @chmod 666 $MDEV
zero    root:root 0666
grsec   root:root 0660
full    root:root 0666

random  root:root 0666
urandom root:root 0444
hwrandom root:root 0660

# console does already exist; therefore ownership has to
# be changed with command
console root:tty 0600 @mkdir -pm 755 fd && cd fd && for x
 ???in 0 1 2 3 ; do ln -sf /proc/self/fd/$x $x; done

kmem    root:root 0640
mem     root:root 0640
port    root:root 0640
ptmx    root:tty 0666

# ram.*
ram([0-9]*)     root:disk 0660 >rd/%1
loop([0-9]+)    root:disk 0660 >loop/%1
sd[a-z].*       root:disk 0660 */lib/mdev/usbdisk_link
hd[a-z][0-9]*   root:disk 0660 */lib/mdev/ide_links

tty             root:tty 0666
tty[0-9]        root:root 0600
tty[0-9][0-9]   root:tty 0660
ttyO[0-9]*      root:tty 0660
pty.*           root:tty 0660
vcs[0-9]*       root:tty 0660
vcsa[0-9]*      root:tty 0660

ttyLTM[0-9]     root:dialout 0660 @ln -sf $MDEV modem
ttySHSF[0-9]    root:dialout 0660 @ln -sf $MDEV modem
slamr           root:dialout 0660 @ln -sf $MDEV slamr0
slusb           root:dialout 0660 @ln -sf $MDEV slusb0
fuse            root:root  0666

# misc stuff
agpgart         root:root 0660  >misc/
psaux           root:root 0660  >misc/
rtc             root:root 0664  >misc/

# input stuff
event[0-9]+     root:root 0640 =input/
ts[0-9]         root:root 0600 =input/

# v4l stuff
vbi[0-9]        root:video 0660 >v4l/
video[0-9]      root:video 0660 >v4l/

# load drivers for usb devices
usbdev[0-9].[0-9]       root:root 0660 */lib/mdev/usbdev
usbdev[0-9].[0-9]_.*    root:root 0660
EOF



# creating /boot/grub/grub.cfg
cat > ${LJOS}/boot/grub/grub.cfg<< "EOF"

set default=0
set timeout=5

set root=(hd0,1)

menuentry "Linux OS DIY minimal" {
        linux   /boot/vmlinuz-6.1.12 root=/dev/sda1 ro quiet
}
EOF



# initialize the log files and give them proper permissions
touch ${LJOS}/var/run/utmp ${LJOS}/var/log/{btmp,lastlog,wtmp}
chmod -v 664 ${LJOS}/var/run/utmp ${LJOS}/var/log/lastlog



# Building the Cross Compiler
unset CFLAGS
unset CXXFLAGS


export LJOS_HOST=$(echo ${MACHTYPE} | sed "s/-[^-]*/-cross/")
export LJOS_TARGET=x86_64-unknown-linux-gnu
export LJOS_CPU=k8
export LJOS_ARCH=$(echo ${LJOS_TARGET} | sed -e 's/-.*//' -e 's/i.86/i386/')
export LJOS_ENDIAN=little


# get packages
export PKGS=~/pkgs
mkdir -pv $PKGS

pushd $PKGS
wget http://ftp.riken.jp/Linux/kernel.org/linux/kernel/v6.x/linux-6.1.12.tar.xz
wget http://ftp.riken.jp/GNU/binutils/binutils-2.40.tar.xz
wget http://ftp.riken.jp/GNU/gcc/gcc-12.2.0/gcc-12.2.0.tar.xz
wget http://ftp.riken.jp/GNU/gmp/gmp-6.2.1.tar.bz2
wget http://ftp.riken.jp/GNU/mpfr/mpfr-4.2.0.tar.xz
wget http://ftp.riken.jp/GNU/mpc/mpc-1.3.1.tar.gz
wget http://ftp.riken.jp/GNU/glibc/glibc-2.37.tar.xz
wget https://www.busybox.net/downloads/busybox-1.36.0.tar.bz2
wget http://ftp.clfs.org/pub/clfs/conglomeration/bootscripts-clfs-embedded/bootscripts-clfs-embedded-1.0-pre5.tar.bz2
wget https://www.zlib.net/fossils/zlib-1.2.13.tar.gz
popd

# M4
pushd $PKGS
tar xJf m4-1.4.19.tar.xz
cd m4-1.4.19
./configure --prefix=/usr/local/m4
make
make install
export PATH=/usr/local/m4/bin:$PATH
export PATH=/usr/local/m4:$PATH
popd

# bison
pushd $PKGS
tar xJf bison-3.8.tar.xz
cd bison-3.8
./configure
make
make install
export PATH=/usr/local/bin:$PATH
export PATH=/usr/local/bin/bison:$PATH
popd

# Kernel Headers
# The kernel's standard header files need to be installed for the cross compiler.
pushd $PKGS
tar xJf linux-6.1.12.tar.xz
cd linux-6.1.12
make mrproper
make ARCH=${LJOS_ARCH} headers_check 
make ARCH=${LJOS_ARCH} INSTALL_HDR_PATH=dest headers_install
cp -rv dest/include/* ${LJOS}/usr/include
popd


# Binutils
# Binutils contains a linker, assembler and other tools needed to handle compiled object files
pushd $PKGS
tar xJf binutils-2.40.tar.xz
cd binutils-2.40
mkdir -v binutils-build
cd binutils-build/
../configure --prefix=${LJOS}/cross-tools \
--target=${LJOS_TARGET} --with-sysroot=${LJOS} \
--disable-nls --enable-shared --disable-multilib
make configure-host && make
ln -sv lib ${LJOS}/cross-tools/lib64
make install
# Copy over the following header file to the target's filesystem
cp -v ../include/libiberty.h ${LJOS}/usr/include
popd


# GCC (Static)
# Before building the final cross-compiler toolchain, ...
# ... first must build a statically compiled toolchain to build the C library (glibc) 
# ... to which the final GCC cross compiler will link
pushd $PKGS
tar xJf gcc-12.2.0.tar.xz
tar xjf gmp-6.2.1.tar.bz2
tar xJf mpfr-4.2.0.tar.xz
tar xzf mpc-1.3.1.tar.gz

mv gmp-6.2.1 gcc-12.2.0/gmp
mv mpfr-4.2.0 gcc-12.2.0/mpfr
mv mpc-1.3.1 gcc-12.2.0/mpc

cd gcc-12.2.0
mkdir -v gcc-static
cd gcc-static/

AR=ar LDFLAGS="-Wl,-rpath,${LJOS}/cross-tools/lib" \
../configure --prefix=${LJOS}/cross-tools \
--build=${LJOS_HOST} --host=${LJOS_HOST} \
--target=${LJOS_TARGET} \
--with-sysroot=${LJOS}/target --disable-nls \
--disable-shared \
--with-mpfr-include=$(pwd)/../mpfr/src \
--with-mpfr-lib=$(pwd)/mpfr/src/.libs \
--without-headers --with-newlib --disable-decimal-float \
--disable-libgomp --disable-libmudflap --disable-libssp \
--disable-threads --enable-languages=c,c++ \
--disable-multilib --with-arch=${LJOS_CPU}

make all-gcc all-target-libgcc 
make install-gcc install-target-libgcc

ln -vs libgcc.a `${LJOS_TARGET}-gcc -print-libgcc-file-name | sed 's/libgcc/&_eh/'`

popd


# Glibc
pushd $PKGS
tar xJf glibc-2.37.tar.xz
cd glibc-2.37
mkdir glibc-build
cd glibc-build/
# Configure build flags
echo "libc_cv_forced_unwind=yes" > config.cache
echo "libc_cv_c_cleanup=yes" >> config.cache
echo "libc_cv_ssp=no" >> config.cache
echo "libc_cv_ssp_strong=no" >> config.cache

BUILD_CC="gcc" CC="${LJOS_TARGET}-gcc" \
AR="${LJOS_TARGET}-ar" \
RANLIB="${LJOS_TARGET}-ranlib" CFLAGS="-O2" \
../configure --prefix=/usr \
--host=${LJOS_TARGET} --build=${LJOS_HOST} \
--disable-profile --enable-add-ons --with-tls \
--enable-kernel=6.1.12 --with-__thread \
--with-binutils=${LJOS}/cross-tools/bin \
--with-headers=${LJOS}/usr/include \
--cache-file=config.cache

make && make install_root=${LJOS}/ install
popd


# GCC (Final)
# build the final GCC cross compiler that will link to the C library built and installed in GCC (Static)
pushd $PKGS
mkdir gcc-build
cd gcc-build/

AR=ar LDFLAGS="-Wl,-rpath,${LJOS}/cross-tools/lib" \
../configure --prefix=${LJOS}/cross-tools \
--build=${LJOS_HOST} --target=${LJOS_TARGET} \
--host=${LJOS_HOST} --with-sysroot=${LJOS} \
--disable-nls --enable-shared \
--enable-languages=c,c++ --enable-c99 \
--enable-long-long \
--with-mpfr-include=$(pwd)/../mpfr/src \
--with-mpfr-lib=$(pwd)/mpfr/src/.libs \
--disable-multilib --with-arch=${LJOS_CPU}

make && make install
cp -v ${LJOS}/cross-tools/${LJOS_TARGET}/lib64/libgcc_s.so.1 ${LJOS}/lib64

export CC="${LJOS_TARGET}-gcc"
export CXX="${LJOS_TARGET}-g++"
export CPP="${LJOS_TARGET}-gcc -E"
export AR="${LJOS_TARGET}-ar"
export AS="${LJOS_TARGET}-as"
export LD="${LJOS_TARGET}-ld"
export RANLIB="${LJOS_TARGET}-ranlib"
export READELF="${LJOS_TARGET}-readelf"
export STRIP="${LJOS_TARGET}-strip"
popd


# Building the Target Image

#   cross compiler => complete 
#   building the components that will be installed on the target image

# BusyBox
# combines a large collection of tiny versions of the most commonly used Linux utilities into a single distributed package
# tools range from common binaries, text editors and command-line shells to filesystem and networking utilities, process management tools and many more
pushd $PKGS
tar -xvjf busybox-1.36.0.tar.bz2
cd busybox-1.36.0

make CROSS_COMPILE="${LJOS_TARGET}-" defconfig
# make CROSS_COMPILE="${LJOS_TARGET}-" menuconfig
make CROSS_COMPILE="${LJOS_TARGET}-"
make CROSS_COMPILE="${LJOS_TARGET}-" CONFIG_PREFIX="${LJOS}" install

cp -v examples/depmod.pl ${LJOS}/cross-tools/bin
chmod 755 ${LJOS}/cross-tools/bin/depmod.pl
popd


# The Linux Kernel
pushd $PKGS
# Change into the kernel package directory
cd linux-6.1.12
make ARCH=${LJOS_ARCH} CROSS_COMPILE=${LJOS_TARGET}- x86_64_defconfig

# Compile and install the kernel
make ARCH=${LJOS_ARCH} CROSS_COMPILE=${LJOS_TARGET}-
make ARCH=${LJOS_ARCH} CROSS_COMPILE=${LJOS_TARGET}- INSTALL_MOD_PATH=${LJOS} modules_install

# copy a few files into the /boot directory for GRUB
cp -v arch/x86/boot/bzImage ${LJOS}/boot/vmlinuz-6.1.12
cp -v System.map ${LJOS}/boot/System.map-6.1.12
cp -v .config ${LJOS}/boot/config-6.1.12

# run the previously installed Perl script provided by the BusyBox package
${LJOS}/cross-tools/bin/depmod.pl -F ${LJOS}/boot/System.map-6.1.12 -b ${LJOS}/lib/modules/6.1.12
popd



# The Bootscripts
pushd $PKGS

tar -xvjf bootscripts-clfs-embedded-1.0-pre5.tar.bz2
cd bootscripts-clfs-embedded-1.0-pre5
# skip: Out of box, one of the package's makefiles contains a line that may not be compatible with your current working shell

make DESTDIR=${LJOS}/ install-bootscripts
ln -sv ../rc.d/startup ${LJOS}/etc/init.d/rcS
popd


# Zlib
pushd $PKGS
tar -xvzf zlib-1.2.13.tar.gz
cd zlib-1.2.13

sed -i 's/-O3/-Os/g' configure
sudo ./configure --prefix=/usr --shared
make && make DESTDIR=/root/lj-os/ install


# some packages may look for Zlib libraries in the /lib directory instead of the /lib64 directory
mv -v ${LJOS}/usr/lib/libz.so.* ${LJOS}/lib
ln -svf ../../lib/libz.so.1 ${LJOS}/usr/lib/libz.so
ln -svf ../../lib/libz.so.1 ${LJOS}/usr/lib/libz.so.1
ln -svf ../lib/libz.so.1 ${LJOS}/lib64/libz.so.1

popd


# Packing target image

cp -rf ${LJOS}/ ${LJOS}-copy

rm -rfv ${LJOS}-copy/cross-tools
rm -rfv ${LJOS}-copy/usr/src/*

# Alternative code
FILES="$(ls ${LJOS}-copy/usr/lib64/*.a)"
# for file in $FILES; do rm -f $file done
rm -rf `echo $FILES`

find ${LJOS}-copy/{,usr/}{bin,lib,sbin} -type f -exec strip --strip-debug '{}' ';'
find ${LJOS}-copy/{,usr/}lib64 -type f -exec strip --strip-debug '{}' ';'

sudo chown -R root:root ${LJOS}-copy
sudo chgrp 13 ${LJOS}-copy/var/run/utmp ${LJOS}-copy/var/log/lastlog
sudo mknod -m 0666 ${LJOS}-copy/dev/null c 1 3
sudo mknod -m 0600 ${LJOS}-copy/dev/console c 5 1
sudo chmod 4755 ${LJOS}-copy/bin/busybox

cd ${LJOS}-copy/

sudo tar cfJ ../ljos-build-$(date +"%m-%d-%y").tar.xz *

echo "Finished"

dd if=/dev/null of=byold02.img bs=1M seek=128
mkfs.ext4 -F byold02.img 
mkdir /mnt/dd-img-tmp
mount -t ext4 -o loop byold02.img /mnt/dd-img-tmp
cd /mnt/dd-img-tmp
tar xJf ../ljos-build-02-17-23.tar.xz

grub-install /mnt/dd-img-tmp
