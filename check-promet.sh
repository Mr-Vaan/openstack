# Cek kenapa crash
docker logs prometheus_node_exporter --tail 20

# Cek semua container prometheus & grafana
docker ps -a | grep -E "grafana|prometheus"

# Fix HAProxy dulu
./fix-haproxy-services.sh

# Cek port 3000
netstat -tulpnt | grep 3000
