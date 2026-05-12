# Tambahkan ke globals.yml agar tidak di-overwrite
cat >> /etc/kolla/config/haproxy-config/mariadb.cfg << 'EOF'
# # This file is managed manually - do not overwrite
EOF
#
# # Buat script post-fix yang bisa dijalankan setelah deploy
cat > ~/fix-mariadb-haproxy.sh << 'EOF'
# #!/bin/bash
cp /etc/kolla/config/haproxy-config/mariadb.cfg /etc/kolla/haproxy/services.d/mariadb.cfg
docker cp /etc/kolla/haproxy/services.d/mariadb.cfg haproxy:/etc/haproxy/services.d/mariadb.cfg
docker restart haproxy
echo "mariadb.cfg restored and haproxy restarted"
EOF
chmod +x ~/fix-mariadb-haproxy.sh
