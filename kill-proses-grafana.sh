# Cek PID grafana yang jalan di host
ps aux | grep grafana | grep -v docker | grep -v grep

# Kill process grafana yang jalan di host (PID 2278)
kill -9 2278

# Verifikasi port 3000 sudah bebas
ss -tlnp | grep 3000

# Start haproxy
docker start haproxy
sleep 5
docker ps | grep haproxy

# Verifikasi
ss -tlnp | grep 3000
nc -zv 192.168.0.130 3000
