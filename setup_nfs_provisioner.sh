#!/bin/bash

#------------- variables definition
NFS_IP=
NFS_PATH=

#------------- check that variables are defined
func_check_variable() {
	
	local ERROR_PRESENCE=0

	if [ -z ${NFS_IP} ] ; then
		logger -s "[Error] NFS_IP is not defined." ; ERROR_PRESENCE=1 ; fi
	if [ -z ${NFS_PATH} ] ; then
		logger -s "[Error] NFS_PATH is not defined." ; ERROR_PRESENCE=1 ; fi

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

	# Internet connection check
	ping -c 5 8.8.8.8 &> /dev/null
	if [ $? -ne 0 ] ; then
		logger -s "[Error] Network is unreachable."
		exit 1
	fi
	logger -s "[INFO] Network is reachable."

	# check nfs server is reachable
	ping -c 5 ${NFS_IP} &> /dev/null
	if [ $? -ne 0 ] ; then
		logger -s "[Error] nfs server is unreachable."
		exit 1
	fi
	logger -s "[INFO] nfs server is reachable."
}

#----------- call checking functions
func_check_variable
func_check_prerequisite

#------------- add nfs provisioner repository
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/

#------------- install nfs provisioner
helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --set nfs.server=${NFS_IP} \
    --set nfs.path=${NFS_PATH}

#------------- set nfs-client as default storage class
kubectl patch storageclass nfs-client -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
