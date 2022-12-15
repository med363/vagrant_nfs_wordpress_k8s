#!/bin/bash
#Kubespray is a composition of Ansible playbooks, inventory, provisioning tools, and domain knowledge for generic OS/Kubernetes clusters
#on traite les variable si l'argument $1 yes
if [[ "$1" == "y" ]];then
INGRESS="NGINX"
fi
#grace au resolution DNS et etchost on recupere les  ips correspandant
IP_HAPROXY=$(dig +short autohaprox)

prepare_kubespray(){

echo
echo "## 1. Git clone kubepsray"
git clone https://github.com/kubernetes-sigs/kubespray.git
chown -R vagrant /home/vagrant/kubespray


echo
echo "## 2. Install requirements"
pip3 install --quiet -r kubespray/requirements.txt

echo
echo "## 3. ANSIBLE | copy sample inventory"
cp -rfp kubespray/inventory/sample kubespray/inventory/mykub

echo
echo "## 4. ANSIBLE | change inventory"
#NR c'est le numero de ligne
#$2 recupere son nom
cat /etc/hosts | grep autokm | awk '{print $2" ansible_host="$1" ip="$1" etcd_member_name=etcd"NR}'>kubespray/inventory/mykub/inventory.ini
cat /etc/hosts | grep autokn | awk '{print $2" ansible_host="$1" ip="$1}'>>kubespray/inventory/mykub/inventory.ini

echo "[kube-master]">>kubespray/inventory/mykub/inventory.ini
cat /etc/hosts | grep autokm | awk '{print $2}'>>kubespray/inventory/mykub/inventory.ini

echo "[etcd]">>kubespray/inventory/mykub/inventory.ini
cat /etc/hosts | grep autokm | awk '{print $2}'>>kubespray/inventory/mykub/inventory.ini

echo "[kube-node]">>kubespray/inventory/mykub/inventory.ini
cat /etc/hosts | grep autokn | awk '{print $2}'>>kubespray/inventory/mykub/inventory.ini

echo "[calico-rr]">>kubespray/inventory/mykub/inventory.ini
echo "[k8s-cluster:children]">>kubespray/inventory/mykub/inventory.ini
echo "kube-master">>kubespray/inventory/mykub/inventory.ini
echo "kube-node">>kubespray/inventory/mykub/inventory.ini
echo "calico-rr">>kubespray/inventory/mykub/inventory.ini

#on pose la question a notre user s'il utilise nginx qd on mettre $1==y
if [[ "$INGRESS" == "NGINX" ]]; then
echo
echo "## 5.1 ANSIBLE | active ingress controller nginx"
#decommenter les ligne dans les fichier yml
sed -i s/"ingress_nginx_enabled: false"/"ingress_nginx_enabled: true"/g kubespray/inventory/mykub/group_vars/k8s-cluster/addons.yml
sed -i s/"# ingress_nginx_host_network: false"/"# ingress_nginx_host_network: true"/g kubespray/inventory/mykub/group_vars/k8s-cluster/addons.yml
sed -i s/"# ingress_nginx_nodeselector:"/"ingress_nginx_nodeselector:"/g kubespray/inventory/mykub/group_vars/k8s-cluster/addons.yml
sed -i s/"#   kubernetes.io\/os: \"linux\""/"  kubernetes.io\/os: \"linux\""/g kubespray/inventory/mykub/group_vars/k8s-cluster/addons.yml
sed -i s/"# ingress_nginx_namespace: \"ingress-nginx\""/"ingress_nginx_namespace: \"ingress-nginx\""/g kubespray/inventory/mykub/group_vars/k8s-cluster/addons.yml
sed -i s/"# ingress_nginx_insecure_port: 80"/"ingress_nginx_insecure_port: 80"/g kubespray/inventory/mykub/group_vars/k8s-cluster/addons.yml
sed -i s/"# ingress_nginx_secure_port: 443"/"ingress_nginx_secure_port: 443"/g kubespray/inventory/mykub/group_vars/k8s-cluster/addons.yml
fi


echo
echo "## 5.x ANSIBLE | active external LB"
sed -i s/"## apiserver_loadbalancer_domain_name: \"elb.some.domain\""/"apiserver_loadbalancer_domain_name: \"autoelb.kub\""/g kubespray/inventory/mykub/group_vars/all/all.yml
sed -i s/"# loadbalancer_apiserver:"/"loadbalancer_apiserver:"/g kubespray/inventory/mykub/group_vars/all/all.yml
sed -i s/"#   address: 1.2.3.4"/"  address: ${IP_HAPROXY}"/g kubespray/inventory/mykub/group_vars/all/all.yml
sed -i s/"#   port: 1234"/"  port: 6443"/g kubespray/inventory/mykub/group_vars/all/all.yml
}

#preparation des cles et poussez vers les nodes
create_ssh_for_kubespray(){
echo 
echo "## 6. SSH | ssh private key and push public key"
sudo -u vagrant bash -c "ssh-keygen -b 2048 -t rsa -f .ssh/id_rsa -q -N ''"
for srv in $(cat /etc/hosts | grep autok | awk '{print $2}');do
cat /home/vagrant/.ssh/id_rsa.pub | sshpass -p 'vagrant' ssh -o StrictHostKeyChecking=no vagrant@$srv -T 'tee -a >> /home/vagrant/.ssh/authorized_keys'
done
}

#lancer kubespray
run_kubespray(){
echo
echo "## 7. ANSIBLE | Run kubepsray"
sudo su - vagrant bash -c "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i kubespray/inventory/mykub/inventory.ini -b -u vagrant kubespray/cluster.yml"
}

#install kubectl en local sur le master
install_kubectl(){
echo
echo "## 8. KUBECTL | Install"
apt-get update && sudo apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
apt-get update -qq 2>&1 >/dev/null
apt-get install -qq -y kubectl 2>&1 >/dev/null
mkdir -p /home/vagrant/.kube
chown -R vagrant /home/vagrant/.kube
echo
echo "## 9. KUBECTL | copy cert"
ssh -o StrictHostKeyChecking=no -i /home/vagrant/.ssh/id_rsa vagrant@${IP_KMASTER} "sudo cat /etc/kubernetes/admin.conf" >/home/vagrant/.kube/config
}



#cree l'inventor ,modiery les ficher de configuration
prepare_kubespray
#cree ssh (deploy le cle public sur les serveurs)
create_ssh_for_kubespray
#l'ancee la cmmande ansible qui va faire tout ses installation    
run_kubespray
#on install kubectl sur la machine de deployement
install_kubectl
