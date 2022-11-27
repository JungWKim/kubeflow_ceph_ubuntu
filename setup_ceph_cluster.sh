#!/bin/bash

#------------- install rook admission controller
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.7.1/cert-manager.yaml

#------------- load rbd module
modprobe rbd
echo rbd | tee -a /etc/modules

#------------- download rook ceph repository
git clone --single-branch --branch v1.10.6 https://github.com/rook/rook.git

#------------- install rook operator by helm
sed -i "s/enableDiscovertyDaemon\: false/enableDiscovertyDaemon\: true/" rook/deploy/charts/rook-ceph/values.yaml
sed -i "s/tag\: VERSION/tag\: v1.10.6/" rook/deploy/charts/rook-ceph/values.yaml
helm repo add rook-release https://charts.rook.io/release
helm install --create-namespace --namespace rook-ceph rook-ceph rook-release/rook-ceph -f rook/deploy/charts/rook-ceph/values.yaml
sleep 5

#------------- create ceph cluster
kubectl apply -f rook/deploy/examples/cluster.yaml
sleep 5

#------------- install rook toolbox
kubectl apply -f rook/deploy/examples/toolbox.yaml
sleep 5

#------------- check ceph status
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph status

#------------- enable toolbok telemery
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph telemetry on
