# Kill grafana process liar di host
pkill -9 grafana

# Restart HAProxy
docker restart haproxy
sleep 3

# Fix services
./fix-haproxy-services.sh

# Verifikasi
netstat -tulpnt | grep -E "5000|8776|3000"
