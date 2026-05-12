# Cek isi grafana.cfg di container HAProxy
docker exec haproxy cat /etc/haproxy/services.d/grafana.cfg

# Cek apakah haproxy load grafana.cfg
docker exec haproxy haproxy -f /etc/haproxy/haproxy.cfg \
  -f /etc/haproxy/services.d/ -c 2>&1 | grep -i "grafana\|error\|warning"

# Cek port yang HAProxy listen
docker exec haproxy ss -tlnp | grep haproxy
