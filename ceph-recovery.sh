#!/usr/bin/env bash
# ceph-recover.sh - pulihkan service Ceph (cephadm) yang mati setelah reboot/power loss
#
# Wajib sudah bisa Akses SSH Tanpa Password(menggunakan RSA or ed25519) dari setiap masing-masing server.
# Diwajibkan menggunakan User root.
# Pemakaian:
#   ./ceph-recover.sh local              # perbaiki host ini saja (jalankan sebagai root)
#   ./ceph-recover.sh all                # semua host di HOSTS via SSH, lalu cek cluster
#   ./ceph-recover.sh finish             # ceph osd in + cek PG (jalankan di node dengan ceph CLI)
#   ./ceph-recover.sh finish --unset-noout   # sekalian lepas flag noout jika PG sudah aman
#   ./ceph-recover.sh status             # ringkasan status cluster
#
# Variabel opsional:
#   HOSTS="Openstack-Controller01 Openstack-Controller02 Openstack-Controller03"
#   FSID=<fsid cluster>   (default: terdeteksi otomatis dari /var/lib/ceph)
#   SSH_USER=root  WAIT=300 (detik maksimal tunggu PG)

set -u

HOSTS="${HOSTS:-Openstack-Controller01 Openstack-Controller02 Openstack-Controller03}" # Sesuaikan dengan Host masing-masing.
SSH_USER="${SSH_USER:-root}"
WAIT="${WAIT:-300}"
FSID="${FSID:-$(ls /var/lib/ceph 2>/dev/null | grep -E '^[0-9a-f]{8}-[0-9a-f]{4}-' | head -1)}"
FSID="${FSID:-f819fa92-33bf-11f1-af0c-000c29a93e61}"

log()  { echo -e "\n[$(date +%H:%M:%S)] $*"; }
warn() { echo -e "[WARN] $*"; }

# ---------------------------------------------------------------- local
local_fix() {
  [ "$(id -u)" -eq 0 ] || { echo "Harus root"; exit 1; }
  log "=== $(hostname) | FSID=$FSID ==="

  log "Cek disk"
  df -h / /var/lib/ceph 2>/dev/null | awk 'NR>1{print}' | sort -u
  df --output=pcent / | tail -1 | tr -dc '0-9' | { read -r p; [ "${p:-0}" -ge 90 ] && warn "Root disk >= 90%, bersihkan dulu!"; }

  log "Aktifkan LVM Ceph"
  for vg in $(vgs --noheadings -o vg_name 2>/dev/null | awk '/ceph-/{print $1}'); do
    vgchange -ay "$vg" >/dev/null 2>&1 && echo "VG aktif: $vg"
  done

  log "Pastikan ceph.target enabled"
  systemctl enable "ceph-$FSID.target" ceph.target >/dev/null 2>&1
  systemctl start ceph.target >/dev/null 2>&1

  log "Reset failed state"
  systemctl reset-failed 'ceph-*' 2>/dev/null

  # service yang failed, OSD dulu, lalu yang lain (mgr, exporter, dll)
  failed=$(systemctl list-units "ceph-$FSID@*" --all --no-legend --plain --no-pager 2>/dev/null \
           | grep -E 'failed|inactive|dead' | grep -o "ceph-$FSID@[^ ]*\.service")
  # reset-failed menghapus state failed, jadi cek juga dari cephadm
  failed_all=$(printf "%s\n" "$failed"; systemctl list-unit-files "ceph-$FSID@*" --no-legend --plain 2>/dev/null \
               | awk '{print $1}' | grep -E "@(osd|mgr|mds|rgw)\." )
  units=$(printf "%s\n" "$failed_all" | sort -u | grep -v '^$' | grep -v '@\.service')

  osd_units=$(printf "%s\n" "$units" | grep '@osd\.')
  other_units=$(printf "%s\n" "$units" | grep -vE '@osd\.|@mon\.|@node-exporter|@grafana|@prometheus|@alertmanager')

  log "Start OSD"
  for u in $osd_units; do
    if systemctl is-active --quiet "$u"; then
      echo "sudah aktif : $u"
    else
      systemctl restart "$u" && echo "restart OK  : $u" || warn "gagal restart $u"
      sleep 5
    fi
  done

  log "Start mgr/mds/lainnya"
  for u in $other_units; do
    if systemctl is-active --quiet "$u"; then
      echo "sudah aktif : $u"
    else
      systemctl restart "$u" && echo "restart OK  : $u" || warn "gagal restart $u"
    fi
  done

  sleep 15
  log "Hasil di $(hostname)"
  systemctl list-units "ceph-$FSID@*" --all --no-legend --plain --no-pager | awk '{printf "%-70s %s/%s\n",$1,$3,$4}'

  bad=$(systemctl list-units "ceph-$FSID@*" --state=failed --no-legend --plain --no-pager | awk '{print $1}')
  if [ -n "$bad" ]; then
    warn "Masih failed:\n$bad"
    for u in $(echo "$bad" | head -3); do
      echo "--- journalctl $u (20 baris) ---"
      journalctl -u "$u" -n 20 --no-pager
    done
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------- cluster
cluster_status() {
  command -v ceph >/dev/null || { warn "perintah ceph tidak ada di host ini"; return 1; }
  log "Status cluster"
  ceph -s
  echo; ceph osd tree | head -40
}

cluster_finish() {
  command -v ceph >/dev/null || { warn "perintah ceph tidak ada di host ini"; return 1; }
  local unset_noout="${1:-}"

  log "Masukkan kembali OSD yang out"
  for id in $(ceph osd dump 2>/dev/null | awk '/^osd\.[0-9]+ / && / out /{sub("osd.","",$1); print $1}'); do
    ceph osd in "$id"
  done

  log "Tunggu PG aktif (maks ${WAIT}s)"
  t=0
  while [ "$t" -lt "$WAIT" ]; do
    h=$(ceph health detail 2>/dev/null)
    if ! echo "$h" | grep -qiE 'inactive|peering|down|incomplete|stale|unknown'; then
      echo "PG tidak ada yang inactive/down."
      break
    fi
    echo "[$t s] masih recovery..."; ceph pg stat 2>/dev/null; sleep 15; t=$((t+15))
  done

  cluster_status

  if [ "$unset_noout" = "--unset-noout" ]; then
    if ceph health detail 2>/dev/null | grep -qiE 'inactive|incomplete|stale|osds? down'; then
      warn "Cluster belum aman, flag noout TIDAK dilepas."
    else
      ceph osd unset noout && echo "noout dilepas."
    fi
  else
    echo -e "\nFlag noout masih aktif. Lepas setelah HEALTH_OK:  ceph osd unset noout"
  fi
}

# ---------------------------------------------------------------- all
run_all() {
  me=$(hostname)
  for h in $HOSTS; do
    if [ "$h" = "$me" ]; then
      local_fix
    else
      log ">>> SSH ke $h"
      ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$SSH_USER@$h" \
          "FSID=$FSID bash -s -- local" < "$0" || warn "gagal di $h"
    fi
  done
  cluster_finish "${1:-}"
}

case "${1:-}" in
  local)  local_fix ;;
  all)    run_all "${2:-}" ;;
  finish) cluster_finish "${2:-}" ;;
  status) cluster_status ;;
  *) sed -n '2,15p' "$0" ;;
esac
