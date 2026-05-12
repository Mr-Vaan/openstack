# Cek apakah variable ter-set
echo $OS_CACERT
env | grep OS_

# Force export
export OS_CACERT=/etc/kolla/certificates/ca/root.crt
export OS_AUTH_URL=https://192.168.0.130:5000

# Test keystone dulu
openstack token issue
