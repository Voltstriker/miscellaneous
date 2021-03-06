#!/bin/bash

# Daniel Fernandez Rodriguez <gmail.com daferoes>
# https://github.com/danifr/miscellaneous
#
# This script will download, build and install/update OpenAFS
#
#
# Usage: sh openafs_update.sh $OPENAFS_RELEASE
#    Ex: sh openafs_update.sh 1.6.18.2
#

OPENAFS_RELEASE=$1
WORKING_DIR='/tmp'
EPEL_RPM='http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-8.noarch.rpm'

if [[ $UID -ne 0 ]]; then
  echo '[ERROR] You need to run this program as root... Exiting'
  exit 1
fi

echo "[INFO] Changing working directory to $WORKING_DIR..."
cd $WORKING_DIR

echo -n "Do you want to install all dependencies? [recommended] (Y/n) "
read COMPLETE

if [[ ${COMPLETE,,} == 'y' ]]; then

  if [[ $(cat /etc/system-release) == *CentOS* ]]; then
    echo "[INFO] Enabling EPEL Repository..."
    wget $EPEL_RPM > /dev/null
    rpm -ivh epel-release-7-8.noarch.rpm
  fi

  echo "[INFO] Installing dependencies..."
  yum install -y rpm-build bison flex kernel-devel kernel-devel-x86_64 \
  krb5-devel ncurses-devel pam-devel perl-ExtUtils-Embed perl-devel wget

  yum groupinstall -y 'Development Tools'
  yum install -y krb5-workstation

  echo "[INFO] Configuring krb5.conf file..."
  wget http://linux.web.cern.ch/linux/docs/krb5.conf -O /etc/krb5.conf
  echo "[INFO] Everything seems OK. Let's start with the OpenAFS upgrade..."
fi

echo "[INFO] Downloading openafs-$OPENAFS_RELEASE..."
if [[ $OPENAFS_RELEASE != *pre* ]]; then
  wget -A src.rpm -r -l 1 -nd --quiet -e robots=off \
  https://www.openafs.org/dl/openafs/$OPENAFS_RELEASE/ > /dev/null
else
  wget -A src.rpm -r -l 1 -nd --quiet -e robots=off \
  https://www.openafs.org/dl/openafs/candidate/$OPENAFS_RELEASE/ > /dev/null
fi

# some bash magic to get OpenAFS full version (release + compilation)
FILENAME=$(ls *.src.rpm)
echo "[INFO] $FILENAME successfully downloaded"
OPENAFS_RELEASE_FULL=${FILENAME%.src.rpm}
OPENAFS_RELEASE=${OPENAFS_RELEASE_FULL##*openafs-}

echo "[INFO] Rebuilding package..."
rpmbuild --rebuild $FILENAME
cd ~/rpmbuild/RPMS/x86_64/

# more bash magic to get KERNEL_VERSION and ARCHITECTURE from uname -r
KERNEL_RELEASE=$(uname -r)
KERNEL_RELEASE_ARRAY=(${KERNEL_RELEASE//./ })
ARRAY_LENGTH=${#KERNEL_RELEASE_ARRAY[@]}

ARCH="${KERNEL_RELEASE_ARRAY[$ARRAY_LENGTH-2]}.${KERNEL_RELEASE_ARRAY[$ARRAY_LENGTH-1]}"

KERNEL_VERSION=${KERNEL_RELEASE%.$ARCH}
KERNEL_VERSION=${KERNEL_VERSION//-/_}

echo [INFO] Installing OpenAFS v$OPENAFS_RELEASE for kernel $KERNEL_VERSION ARCH $ARCH

rm -f openafs-kpasswd-* openafs-server*
yum install -y *.rpm

THISCELL_DIR='/usr/vice/etc/'
echo "[INFO] Creating $THISCELL_DIR directory..."
mkdir -p $THISCELL_DIR
echo "cern.ch" > $THISCELL_DIR/ThisCell

echo "[INFO] Deleting $FILENAME from $WORKING_DIR..."
rm $WORKING_DIR/$FILENAME

echo "[INFO] Restarting openafs-client service..."
systemctl restart openafs-client.service
if [ $? -eq 0 ]; then
  echo '[INFO] All done :D'
  echo '[INFO] To start using it, you will need valid kerberos ticket:

    kinit <username>@CERN.CH

And also mount the afs share on the our system:

    aklog -c cern.ch -k CERN.CH

After doing it, you will be able to access your personal share from:

    /afs/cern.ch/user/<first_letter_username>/<username>
'
else
  echo "[ERROR] Failed to start openafs-client.service. Please check error trace."
  exit 1
fi
