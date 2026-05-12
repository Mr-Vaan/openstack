#!/bin/bash
echo "=== Syncing all HAProxy service configs ==="
for f in /etc/kolla/haproxy/services.d/*.cfg; do
  name=$(basename $f)
  if [ -s "$f" ]; then
    docker cp $f haproxy:/etc/haproxy/services.d/$name
    echo "Copied: $name"
  fi
done

echo "=== Validating HAProxy config ==="
docker exec haproxy haproxy -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/services.d/ -c

echo "=== Restarting HAProxy ==="
docker restart haproxy
echo "Done!"
