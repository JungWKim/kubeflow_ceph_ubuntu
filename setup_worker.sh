#!/bin/bash

#------------- variables definition
ADMIN=
ADMIN_HOME=/home/${ADMIN}
IP=

#------------- check that variables are defined
func_check_variable() {
	
	local ERROR_PRESENCE=0

	if [ -z ${ADMIN} ] ; then
		logger -s "[Error] ADMIN is not defined." ; ERROR_PRESENCE=1 ; fi
	if [ -z ${ADMIN_HOME} ] ; then
		logger -s "[Error] ADMIN_HOME is not defined." ; ERROR_PRESENCE=1 ; fi
	if [ -z ${IP} ] ; then
		logger -s "[Error] IP is not defined." ; ERROR_PRESENCE=1 ; fi

	if [ ${ERROR_PRESENCE} -eq 1 ] ; then
		exit 1
	fi	
}

#----------- prerequisite checking function definition
func_check_prerequisite () {

	# /etc/os-release file existence check
	if [ ! -e "/etc/os-release" ] ; then
		logger -s "[Error] /etc/os-release doesn't exist. OS is unrecognizable."
		exit 1
	else
		# check OS distribution
		local OS_DIST=$(. /etc/os-release;echo $ID$VERSION_ID)

		if [ "${OS_DIST}" != "ubuntu22.04" ] ; then
			logger -s "[Error] OS distribution doesn't match ubuntu22.04"
			exit 1
		fi
		logger -s "[INFO] OS distribution matches ubuntu22.04"
	fi

	# check ADMIN account exists
	grep ${ADMIN} /etc/passwd &> /dev/null
	if [ $? -ne 0 ] ; then
		logger -s "${ADMIN} doesn't exist." ; exit 1
	fi

	# ADMIN HOME existence check
	if [ ! -d ${ADMIN_HOME} ] ; then
		logger -s "[Error] ADMIN HOME directory doesn't exist";exit 1
	fi
	logger -s "[INFO] ADMIN HOME directory exists."

	# Internet connection check
	ping -c 5 8.8.8.8 &> /dev/null
	if [ $? -ne 0 ] ; then
		logger -s "[Error] Network is unreachable.";exit 1
	fi
	logger -s "[INFO] Network is reachable."

	# check /etc/docker/daemon.json exists
	if [ -e /etc/docker/daemon.json ] ; then
		logger -s "/etc/docker/daemon.json already exists. Please backup the existing one." ; exit 1
	fi

	local ANSWER
	# Ask hostname and ip are fixed
	read -e -p "Did you fix hostname and ip?(yes/no) " ANSWER
	case "${ANSWER}" in
		[yY][eE][sS] | [yY])
			for COUNT in {5..1} ; do
				echo "Start to install k8s before ${COUNT}s..."
				sleep 1
			done
			;;
		[nN][oO] | [nN])
			logger -s "Exiting Program..."
			exit 1
			;;
		*)
			logger -s "[Error] Wrong input..."
			exit 1
			;;
	esac
}

#----------- call checking functions
func_check_variable
func_check_prerequisite

#------------- disable outdated librareis pop up
sed -i "s/\#\$nrconf{restart} = 'i'/\$nrconf{restart} = 'a'/g" /etc/needrestart/needrestart.conf

#------------- disable kernel upgrade hint pop up
sed -i "s/\#\$nrconf{kernelhints} = -1/\$nrconf{kernelhints} = 0/g" /etc/needrestart/needrestart.conf

#------------- install basic packages
sed -i 's/1/0/g' /etc/apt/apt.conf.d/20auto-upgrades
apt install -y net-tools whois

#------------- disable ufw
systemctl stop ufw
systemctl disable ufw

#------------- disable swap partition
swapoff -a
sed -i.copy '/swap/ s/^/#/' /etc/fstab

#------------- install docker
apt update
apt install -y ca-certificates curl gnupg lsb-release
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

#-------------- make docker use systemd not cgroupfs
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

mkdir -p /etc/systemd/system/docker.service.d
systemctl daemon-reload
systemctl restart docker

#------------- letting iptables see bridged traffic
echo "br_netfilter" >> /etc/modules-load.d/k8s.conf
echo "net.bridge.bridge-nf-call-iptables=1" >> /etc/sysctl.d/k8s.conf
echo "net.bridge.bridge-nf-call-ip6tables=1" >> /etc/sysctl.d/k8s.conf
sysctl --system

#------------- install kubeadm/kubelete/kubectl
apt-get update
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet=1.20.11-00 kubeadm=1.20.11-00 kubectl=1.20.11-00
apt-mark hold kubelet kubeadm kubectl

#------------- enable kubectl & kubeadm auto-completion
echo "source <(kubectl completion bash)" >> ${ADMIN_HOME}/.bashrc
echo "source <(kubeadm completion bash)" >> ${ADMIN_HOME}/.bashrc

echo "source <(kubectl completion bash)" >> $HOME/.bashrc
echo "source <(kubeadm completion bash)" >> $HOME/.bashrc
source $HOME/.bashrc

#------------- load rbd module
echo rbd | tee -a /etc/modules
