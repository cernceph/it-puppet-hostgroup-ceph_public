#!/bin/bash

CEPH_OSD_ONDISK_MAGIC='ceph osd volume v026'

JOURNAL_UUID='45b0969e-9b03-4f30-b4c6-b4b80ceff106'
DMCRYPT_JOURNAL_UUID='45b0969e-9b03-4f30-b4c6-5ec00ceff106'
OSD_UUID='4fbd7e29-9d25-41b8-afd0-062c0ceff05d'
DMCRYPT_OSD_UUID='4fbd7e29-9d25-41b8-afd0-5ec00ceff05d'
TOBE_UUID='89c57f98-2fe5-4dc0-89c1-f3ad0ceff2be'
DMCRYPT_TOBE_UUID='89c57f98-2fe5-4dc0-89c1-5ec00ceff2be'


lsscsi | grep INTEL
ceph-disk list | grep 'ceph journal'

read -p "Continue? " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi


for disk in sda sdb sdc sdd; do
  for i in {1..5}; do
    sgdisk --new=$i:0:+20480M --change-name=$i:'ceph journal' --partition-guid=$i:`uuid -v4` --typecode=$i:$JOURNAL_UUID --mbrtogpt -- /dev/$disk
  done
done
