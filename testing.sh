# Test semua service
netstat -tulpnt | grep -E "3000|5000|8776|9090"

# Unset dan source ulang
for key in $(set | awk '{FS="="}  /^OS_/ {print $1}'); do unset $key; done
source /etc/kolla/admin-openrc.sh

# Test Cinder
openstack volume service list

# Test buat volume
openstack volume create --size 1 test-volume
openstack volume list
