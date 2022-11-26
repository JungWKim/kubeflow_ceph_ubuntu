#!/bin/bash

#------------- variables definition
ADMIN=
ADMIN_HOME=/home/${ADMIN}
MASTER_IP=

#------------- check that variables are defined
func_check_variable() {
	
	local ERROR_PRESENCE=0

	if [ -z ${ADMIN} ] ; then
		logger -s "[Error] ADMIN is not defined." ; ERROR_PRESENCE=1 ; fi
	if [ -z ${ADMIN_HOME} ] ; then
		logger -s "[Error] ADMIN_HOME is not defined." ; ERROR_PRESENCE=1 ; fi
	if [ -z ${MASTER_IP} ] ; then
		logger -s "[Error] MASTER_IP is not defined." ; ERROR_PRESENCE=1 ; fi

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
}

#----------- call checking functions
func_check_variable
func_check_prerequisite

#---------------- download kubeflow manifest repository
git clone https://github.com/kubeflow/manifests.git -b v1.5-branch
mv manifests ${ADMIN_HOME}/

#---------------- enable kubeflow to be accessed through https (1)
cat << EOF >> ${ADMIN_HOME}/manifests/common/istio-1-11/kubeflow-istio-resources/base/kf-istio-resources.yaml
    tls:
      httpsRedirect: true
  - hosts:
    - '*'
    port:
      name: https
      number: 443
      protocol: HTTPS
    tls:
      mode: SIMPLE
      privateKey: /etc/istio/ingressgateway-certs/tls.key
      serverCertificate: /etc/istio/ingressgateway-certs/tls.crt
EOF

#---------------- enable kubeflow to be accessed through https (2)
sed -i'' -r -e "/env/a\        - name: APP_SECURE_COOKIES\n          value: \"false\"" ${ADMIN_HOME}/manifests/apps/jupyter/jupyter-web-app/upstream/base/deployment.yaml

#---------------- download kustomize 3.2.0 which is stable with kubeflow 1.5.0 then copy it into /bin/bash
wget https://github.com/kubernetes-sigs/kustomize/releases/download/v3.2.0/kustomize_3.2.0_linux_amd64
chmod +x kustomize_3.2.0_linux_amd64
mv kustomize_3.2.0_linux_amd64 /usr/bin/kustomize

#---------------- install kubeflow as a single command
while ! kustomize build ${ADMIN_HOME}/manifests/example | kubectl apply -f -; do echo "Retrying to apply resources"; sleep 10; done

#---------------- create certification for https connection
sed -i 's/MASTER_IP/'"${MASTER_IP}"'/g' files/certificate.yaml
kubectl apply -f files/certificate.yaml

#---------------- how to delete kubeflow
# 1. kubectl delete profile --all
# 2. change directory to manifests
# 3. kustomize build example | kubectl delete -f -
