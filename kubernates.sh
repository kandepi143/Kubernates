read -p "Enter Master ip: " MIP
read -p "Enter Worker ip: " WIP

# Update /etc/hosts
echo $MIP  kmaster.sk.com  kmaster>>/etc/hosts
echo $WIP  kworker.sk.com  kworker>>/etc/hosts

# install, start & enable docker service
yum install -y -q yum-utils device-mapper-persistent-data lvm2 > /dev/null 2>&1
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo > /dev/null 2>&1
yum install -y -q docker-ce >/dev/null 2>&1

systemctl start docker
systemctl enable docker

# Disable SELinux
setenforce 0
sed -i --follow-symlinks 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/sysconfig/selinux

#systemctl stop firewalld
#systemctl disable firewalld

# Disable swap
sed -i '/swap/d' /etc/fstab
swapoff -a

# Update sysctl settings for Kubernates networkin
cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system


# add yum repository
cat >>/etc/yum.repos.d/kubernetes.repo<<EOF
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
        https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

# Install Kubernates & start kubelet
yum install kubeadm kubelet kubectl -y
systemctl start kubelet
systemctl enable kubelet

# Initialize Kubernates Cluster
kubeadm init --apiserver-advertise-address=$MIP --pod-network-cidr=172.16.0.0/16


mkdir /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config

# Deploy flannel network
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml


# generate Token
kubeadm token create --print-join-command>/root/token

# copy hosts file from master to worker
scp /etc/hosts root@$WIP:/etc/hosts

# copy worker_script
scp /root/worker.sh root@$WIP:/root/.

# execute worker.sh
ssh root@$WIP 'sh /root/worker.sh'

# copy token from master to worker
scp /root/token root@$WIP:/root/.

# executing token
ssh root@$WIP 'sh /root/token'
