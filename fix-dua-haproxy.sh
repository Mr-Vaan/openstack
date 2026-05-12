# Cek status haproxy
docker ps -a | grep haproxy

# Lihat kenapa crash
docker logs haproxy --tail 30

# Start ulang haproxy
docker start haproxy
sleep 3
docker ps | grep haproxy
