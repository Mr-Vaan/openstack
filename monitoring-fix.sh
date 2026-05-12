#!/bin/bash

echo "=================================================="
echo " OpenStack Monitoring Fix Script"
echo " Fix Ceph Service Conflict + HAProxy Services"
echo "=================================================="

FSID='f819fa92-33bf-11f1-af0c-000c29a93e61'
NODES="Openstack-Controller01 Openstack-Controller02 Openstack-Controller03"

# ==========================================
# STEP 1 - Test Volume
# ==========================================
echo ""
echo "[STEP 1] Testing Cinder Volume..."
openstack volume create --size 1 test-volume-$(date +%s) 2>/dev/null
sleep 5
openstack volume list

# ==========================================
# STEP 2 - Mask Ceph Monitoring Services
# ==========================================
echo ""
echo "[STEP 2] Masking Ceph monitoring services di semua controller..."
for node in $NODES; do
  echo "  --> Processing $node..."
  ssh $node "
    HOST=\$(hostname)
    FSID='${FSID}'
    systemctl mask ceph-\${FSID}@grafana.\${HOST}.service 2>/dev/null
    systemctl mask ceph-\${FSID}@alertmanager.\${HOST}.service 2>/dev/null
    systemctl mask ceph-\${FSID}@prometheus.\${HOST}.service 2>/dev/null
    systemctl mask ceph-\${FSID}@node-exporter.\${HOST}.service 2>/dev/null
    systemctl stop ceph-\${FSID}@grafana.\${HOST}.service 2>/dev/null
    systemctl stop ceph-\${FSID}@alertmanager.\${HOST}.service 2>/dev/null
    systemctl stop ceph-\${FSID}@prometheus.\${HOST}.service 2>/dev/null
    systemctl stop ceph-\${FSID}@node-exporter.\${HOST}.service 2>/dev/null
    pkill -9 alertmanager 2>/dev/null
    pkill -9 prometheus 2>/dev/null
    echo '  [OK] Masked on '\$HOST
  "
done

# ==========================================
# STEP 3 - Sync HAProxy Services + Restart
# ==========================================
echo ""
echo "[STEP 3] Syncing HAProxy services di semua controller..."
for node in $NODES; do
  echo "  --> Processing $node..."
  ssh $node "
    # Copy semua cfg yang ada isinya
    for f in /etc/kolla/haproxy/services.d/*.cfg; do
      name=\$(basename \$f)
      if [ -s \"\$f\" ]; then
        docker cp \$f haproxy:/etc/haproxy/services.d/\$name 2>/dev/null
      fi
    done

    # Validasi config
    docker exec haproxy haproxy \
      -f /etc/haproxy/haproxy.cfg \
      -f /etc/haproxy/services.d/ -c 2>/dev/null && \
      echo '  [OK] Config valid' || echo '  [ERROR] Config invalid'

    # Restart HAProxy
    docker restart haproxy 2>/dev/null
    sleep 3

    # Cek status
    STATUS=\$(docker inspect --format='{{.State.Status}}' haproxy 2>/dev/null)
    echo '  [OK] HAProxy status: '\$STATUS' on '\$(hostname)
  "
done

# ==========================================
# STEP 4 - Fix HAProxy di Controller01
# ==========================================
echo ""
echo "[STEP 4] Fix HAProxy lokal Controller01..."
for f in /etc/kolla/haproxy/services.d/*.cfg; do
  name=$(basename $f)
  if [ -s "$f" ]; then
    docker cp $f haproxy:/etc/haproxy/services.d/$name 2>/dev/null
    echo "  Copied: $name"
  fi
done
docker restart haproxy 2>/dev/null
sleep 3
echo "  [OK] HAProxy restarted"

# ==========================================
# STEP 5 - Verifikasi Port VIP
# ==========================================
echo ""
echo "[STEP 5] Verifikasi port VIP di Controller01..."
echo "  Ports listening on VIP (192.168.0.130):"
netstat -tulpnt 2>/dev/null | grep "192.168.0.130" | awk '{print "  "$1" "$4}' | sort

# ==========================================
# STEP 6 - Test Semua OpenStack Services
# ==========================================
echo ""
echo "[STEP 6] Testing OpenStack services..."
echo ""
echo "--- Volume Services ---"
openstack volume service list 2>/dev/null || echo "[ERROR] Cinder tidak bisa diakses"

echo ""
echo "--- Compute Services ---"
openstack compute service list 2>/dev/null || echo "[ERROR] Nova tidak bisa diakses"

echo ""
echo "--- Network Agents ---"
openstack network agent list 2>/dev/null || echo "[ERROR] Neutron tidak bisa diakses"

echo ""
echo "--- Hypervisors ---"
openstack hypervisor list 2>/dev/null || echo "[ERROR] Hypervisor tidak bisa diakses"

echo ""
echo "--- Grafana Health ---"
curl -sk https://192.168.0.130:3000/api/health 2>/dev/null | python3 -m json.tool 2>/dev/null || \
  echo "[ERROR] Grafana tidak bisa diakses"

echo ""
echo "=================================================="
echo " Fix Script Selesai!"
echo "=================================================="
