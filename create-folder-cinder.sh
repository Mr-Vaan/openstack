# Buat direktori yang dibutuhkan
mkdir -p /etc/kolla/config/cinder/cinder-volume
mkdir -p /etc/kolla/config/cinder/cinder-backup

# Copy keyring ke lokasi yang benar
cp /etc/kolla/config/cinder/ceph.client.cinder.keyring \
   /etc/kolla/config/cinder/cinder-volume/ceph.client.cinder.keyring

cp /etc/kolla/config/cinder/ceph.conf \
   /etc/kolla/config/cinder/cinder-volume/ceph.conf

# Verifikasi
ls -la /etc/kolla/config/cinder/cinder-volume/
