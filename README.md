
# Jalankan Scpript ini kalo abis deploy lagi

cat > ~/fix-mariadb-haproxy.sh << 'EOF'
#!/bin/bash
cp /etc/kolla/config/haproxy-config/mariadb.cfg /etc/kolla/haproxy/services.d/mariadb.cfg
docker cp /etc/kolla/haproxy/services.d/mariadb.cfg haproxy:/etc/haproxy/services.d/mariadb.cfg
docker restart haproxy
echo "mariadb.cfg restored and haproxy restarted"
EOF
chmod +x ~/fix-mariadb-haproxy.sh

# Alur Deploy :

# 1. Deploy seperti biasa
kolla-ansible -i ~/openstack/multinode deploy

# 2. Setelah deploy selesai, langsung jalankan fix ini
~/fix-mariadb-haproxy.sh

# 3. Baru post-deploy
kolla-ansible -i ~/openstack/multinode post-deploy

# openstack
