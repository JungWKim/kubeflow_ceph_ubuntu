#!/bin/bash

#------------- install rook admission controller
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.7.1/cert-manager.yaml

#------------- download rook ceph repository
git clone --single-branch --branch v1.10.6 https://github.com/rook/rook.git

#------------- install rook operator by helm
#kubectl apply -f rook/deploy/examples/crds.yaml
#kubectl apply -f rook/deploy/examples/common.yaml
#kubectl apply -f rook/deploy/examples/operator.yaml
sed -i "s/enableDiscoveryDaemon\: false/enableDiscoveryDaemon\: true/" rook/deploy/charts/rook-ceph/values.yaml
sed -i "s/tag\: VERSION/tag\: v1.10.6/" rook/deploy/charts/rook-ceph/values.yaml
helm repo add rook-release https://charts.rook.io/release
helm install --create-namespace --namespace rook-ceph rook-ceph rook-release/rook-ceph -f rook/deploy/charts/rook-ceph/values.yaml
sleep 5

#------------- create ceph cluster
#kubectl apply -f rook/deploy/examples/cluster.yaml
sed -i "s/image\: rook\/ceph\:VERSION/image\: rook\/ceph\:v1.10.6/" rook/deploy/charts/rook-ceph-cluster/values.yaml
helm install --create-namespace --namespace rook-ceph rook-ceph-cluster \
   --set operatorNamespace=rook-ceph rook-release/rook-ceph-cluster -f rook/deploy/charts/rook-ceph-cluster/values.yaml
sleep 5

#------------- install rook toolbox
kubectl apply -f rook/deploy/examples/toolbox.yaml
sleep 5

#------------- check ceph status
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph status

#------------- enable toolbok telemery
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph telemetry on
