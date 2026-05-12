# Cek apa yang spawn grafana process
ps auxf | grep grafana | grep -v grep | grep -v docker

# Cek systemd service
systemctl status grafana* 2>/dev/null
systemctl list-units --all | grep grafana

# Cek crontab
crontab -l | grep grafana
cat /etc/cron.d/* | grep grafana 2>/dev/null

# Cek apakah ada di rc.local
cat /etc/rc.local 2>/dev/null | grep grafana
