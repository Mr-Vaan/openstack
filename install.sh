#!/usr/bin/env bash
# Install OpenStack 2025.2 dengan Kolla-Ansible (stable/2025.2)
# Jalankan di DEPLOY/CONTROL HOST (Ubuntu 24.04), sebagai user biasa dengan sudo.
# Taruh file `multinode` dan `globals.yml` di folder yang sama dengan script ini.
set -euo pipefail

VENV=/opt/kolla-venv
BRANCH=stable/2025.2
HOSTS_FILE="$(pwd)/multinode-hosts"
INVENTORY="$(pwd)/multinode"

### 0. Prasyarat di SEMUA node (cek manual dulu)
#  - Netplan bond/VLAN sudah aktif, semua node saling ping lewat VLAN Management
#  - Hostname sesuai inventory + resolve di /etc/hosts tiap node
#  - NTP/chrony sinkron
#  - User deploy bisa SSH tanpa password + sudo NOPASSWD (ssh-copy-id ke semua node)
#  - Di node grup [storage] (lihat multinode-hosts): VG LVM `cinder-volumes` sudah ada (vgs cinder-volumes)
#  - neutron_external_interface (bond0.<PROVIDER>) UP tanpa IP, di 3 controller dan 3 compute
#  - bond0.<PUBLIC_API> (kolla_external_vip_interface) hanya wajib di 3 controller
#  - Layout 6 node: bond0/bond1 + VLAN Mgmt, Internal API, Tenant, Storage ada di semua node

### 1. Dependensi di deploy host
sudo apt update
sudo apt install -y git python3-dev libffi-dev gcc libssl-dev libdbus-glib-1-dev python3-venv

### 2. Virtualenv + Kolla-Ansible
sudo mkdir -p "$VENV" && sudo chown "$USER":"$USER" "$VENV"
python3 -m venv "$VENV"
# shellcheck disable=SC1091
source "$VENV/bin/activate"
pip install -U pip
pip install "git+https://opendev.org/openstack/kolla-ansible@${BRANCH}"

### 3. Konfigurasi
sudo mkdir -p /etc/kolla
sudo chown "$USER":"$USER" /etc/kolla
cp -r "$VENV"/share/kolla-ansible/etc_examples/kolla/* /etc/kolla/
cp ./globals.yml /etc/kolla/globals.yml

# Inventory = bagian atas (multinode-hosts) + sisa group standar dari paket kolla-ansible
STOCK="$VENV/share/kolla-ansible/ansible/inventory/multinode"
grep -q '^\[baremetal:children\]' "$STOCK" || { echo "Marker [baremetal:children] tidak ada di $STOCK, gabungkan inventory manual"; exit 1; }
{ cat "$HOSTS_FILE"; sed -n '/^\[baremetal:children\]/,$p' "$STOCK"; } > "$INVENTORY"
kolla-ansible install-deps          # Ansible Galaxy collections
kolla-genpwd                        # isi /etc/kolla/passwords.yml

### 4. Tes koneksi Ansible
ansible -i "$INVENTORY" all -m ping

### 5. Deploy
kolla-ansible bootstrap-servers -i "$INVENTORY"
kolla-ansible prechecks         -i "$INVENTORY"
kolla-ansible deploy            -i "$INVENTORY"

### 6. Post-deploy + OpenStack CLI
pip install python-openstackclient -c https://releases.openstack.org/constraints/upper/2025.2
kolla-ansible post-deploy -i "$INVENTORY"     # buat /etc/kolla/clouds.yaml
mkdir -p ~/.config/openstack && cp /etc/kolla/clouds.yaml ~/.config/openstack/
echo "Password admin: $(grep keystone_admin_password /etc/kolla/passwords.yml)"
openstack --os-cloud kolla-admin service list
