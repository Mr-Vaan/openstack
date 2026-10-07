#!/usr/bin/env bash
# cleanup-stale-locks.sh
# Lepas exclusive lock RBD yang basi lalu hapus volume Cinder yang tersangkut (ImageBusy).
#
# Pemakaian:
#   ./cleanup-stale-locks.sh                 # pakai daftar default di bawah
#   ./cleanup-stale-locks.sh <ID> <ID> ...   # daftar sendiri
#
# Pengaman: volume dilewati kalau status bukan "available" atau masih punya attachment.
# PERINGATAN: penghapusan volume bersifat permanen.

POOL="${POOL:-volumes}"

DEFAULT_IDS=(
  38db21bf-3e32-4d66-84d2-393705dae0aa   # centos-fix
  6e2fb650-f3a7-4eb9-85fd-603c059efd6d   # ubuntu-rootdisk
  0a1ccc9a-1002-4323-8865-c05548535b2b   # vm-ubuntu
  57688edd-ea9c-4f15-88f3-386cb8ad6799   # disk-2
  dcc52d09-d251-4298-891e-9baff32740b6   # diskwin-1
  c2ae2426-8d42-4212-8684-b7e3523e0229   # web-vol-1-200
)
if [ "$#" -gt 0 ]; then IDS=("$@"); else IDS=("${DEFAULT_IDS[@]}"); fi

source ~/openstack/admin-openrc.sh || { echo "gagal source admin-openrc.sh"; exit 1; }

echo "Volume yang akan DIHAPUS PERMANEN:"
for ID in "${IDS[@]}"; do
  openstack volume show "$ID" -f value -c name -c size -c status 2>/dev/null | paste -sd' ' | sed "s|^|  $ID  |"
done
read -r -p "Ketik YA untuk lanjut: " ans
[ "$ans" = "YA" ] || { echo "Dibatalkan."; exit 0; }

for ID in "${IDS[@]}"; do
  echo; echo "===== $ID"
  st=$(openstack volume show "$ID" -f value -c status 2>/dev/null)
  att=$(openstack volume show "$ID" -f value -c attachments 2>/dev/null)
  if [ "$st" != "available" ] || [ "$att" != "[]" ]; then
    echo "SKIP: status=$st attachments=$att"
    continue
  fi

  rbd -p "$POOL" lock ls "volume-$ID" 2>/dev/null | awk '/^client\./' | \
  while read -r locker w1 w2 addr; do
    echo "lock basi: $locker  \"$w1 $w2\"  $addr"
    ceph osd blocklist add "$addr"
    rbd -p "$POOL" lock rm "volume-$ID" "$w1 $w2" "$locker" && echo "lock dilepas"
  done

  left=$(rbd -p "$POOL" lock ls "volume-$ID" 2>/dev/null | awk '/^client\./' | wc -l)
  if [ "$left" -ne 0 ]; then echo "SKIP: lock masih ada"; continue; fi

  openstack volume delete "$ID" && echo "delete dikirim"
  sleep 5
done

echo; echo "Menunggu proses delete..."; sleep 60
openstack volume list --all-projects

