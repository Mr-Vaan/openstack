# Unset semua OS_ variable lama
for key in $(set | awk '{FS="="}  /^OS_/ {print $1}'); do unset $key; done

# Source ulang
source /etc/kolla/admin-openrc.sh

# Verifikasi variable
echo $OS_AUTH_URL
echo $OS_CACERT

# Test
openstack token issue
openstack volume service list
