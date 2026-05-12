# Cek HAProxy status
docker ps | grep haproxy

# Cek port 5000
netstat -tulpnt | grep 5000

# Fix HAProxy
./fix-haproxy-services.sh

# Cek lagi
netstat -tulpnt | grep 5000

# Test langsung ke node
curl -k https://192.168.0.120:5000
