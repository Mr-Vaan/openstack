for f in /etc/kolla/haproxy/services.d/*.cfg; do
  name=$(basename $f)
  if [ -s "$f" ]; then
    docker cp $f haproxy:/etc/haproxy/services.d/$name
    echo "Copied: $name"
  fi
done

docker exec haproxy haproxy -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/services.d/ -c && \
docker restart haproxy
