#!/bin/bash

#------------- install rook admission controller
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.7.1/cert-manager.yaml

#------------- download rook ceph repository
git clone --single-branch --branch v1.10.6 https://github.com/rook/rook.git

#------------- add two lines in cluster.yaml
sed -i -r -e "/    modules\:/a\      \- name\: rook\\n        enabled\: true" rook/deploy/examples/cluster.yaml
# prepare rook manager module to be used in dashboard

#------------- change the value of ROOK_ENABLE_DISCOVERY_DAEMON to true in operator.yaml
sed -i "s/ROOK_ENABLE_DISCOVERY_DAEMON\: \"false\"/ROOK_ENABLE_DISCOVERY_DAEMON\: \"false\"/" rook/deploy/examples/operator.yaml
# this is to enable 'physical disks' tab in dashboard

#------------- change ROOK_DISCOVER_DEVICES_INTERVAL from 60m to 5s
sed -i "s/60m/5s/" rook/deploy/examples/operator.yaml
# this's going to shorten interval time of "physical disks' tab in dashboard from 60m to 5s

#------------- install rook operator by helm
kubectl apply -f rook/deploy/examples/crds.yaml
kubectl apply -f rook/deploy/examples/common.yaml
kubectl apply -f rook/deploy/examples/operator.yaml
#sed -i "s/enableDiscoveryDaemon\: false/enableDiscoveryDaemon\: true/" rook/deploy/charts/rook-ceph/values.yaml
#sed -i "s/tag\: VERSION/tag\: v1.10.6/" rook/deploy/charts/rook-ceph/values.yaml
#helm repo add rook-release https://charts.rook.io/release
#helm install --create-namespace --namespace rook-ceph rook-ceph rook-release/rook-ceph -f rook/deploy/charts/rook-ceph/values.yaml
sleep 5

#------------- create ceph cluster
kubectl apply -f rook/deploy/examples/cluster.yaml
#sed -i "s/image\: rook\/ceph\:VERSION/image\: rook\/ceph\:v1.10.6/" rook/deploy/charts/rook-ceph-cluster/values.yaml
#helm install --create-namespace --namespace rook-ceph rook-ceph-cluster \
#   --set operatorNamespace=rook-ceph rook-release/rook-ceph-cluster -f rook/deploy/charts/rook-ceph-cluster/values.yaml
sleep 5

#------------- deploy components for block storage
kubectl apply -f rook/deploy/examples/csi/rbd/storageclass.yaml

#------------- deploy components for erasure coded block storage
#kubectl apply -f rook/deploy/examples/csi/rbd/storageclass-ec.yaml

#------------- deploy components for filesystem storage
kubectl apply -f rook/deploy/examples/filesystem.yaml
kubectl apply -f rook/deploy/examples/csi/cephfs/storageclass.yaml
#------------- deploy components for erasure coded filesystem storage
#kubectl apply -f rook/deploy/examples/filesystem-ec.yaml
#kubectl apply -f rook/deploy/examples/csi/cephfs/storageclass-ec.yaml

#------------- deploy components for objectj storage
kubectl apply -f rook/deploy/examples/object.yaml
kubectl apply -f rook/deploy/examples/storageclass-bucket-delete.yaml
kubectl apply -f rook/deploy/examples/object-bucket-claim-delete.yaml

#------------- install rook toolbox
kubectl apply -f rook/deploy/examples/toolbox.yaml
sleep 5

#------------- check ceph status
#kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph status

#------------- enable toolbox telemery
#kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph telemetry on
#kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph telemetry on --license sharing-1-0
#kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph telemetry enable channel perf
#kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph orch set backend

#------------- deploy nodeport of dashboard to access externally
kubectl apply -f rook/deploy/examples/dashboard-external-https.yaml

#------------- below commands prohibit 'physical disks' tab from showing '500 internal error' messages.
#ceph dashboard ac-role-create admin-no-iscsi

#for scope in dashboard-settings log rgw prometheus grafana nfs-ganesha manager hosts rbd-image config-opt rbd-mirroring cephfs user osd pool monitor; do
#    ceph dashboard ac-role-add-scope-perms admin-no-iscsi ${scope} create delete read update ; done

#ceph dashboard ac-user-set-roles admin admin-no-iscsi
