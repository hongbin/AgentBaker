#!/usr/bin/env bash

set -o nounset
set -o pipefail

KUBECTL="/usr/local/bin/kubectl --kubeconfig /var/lib/kubelet/kubeconfig"

source_list_path=/etc/apt/sources.list
source_list_backup_path=/etc/apt/sources.list.backup

node_name=$(hostname)
if [ -z "${node_name}" ]; then
    echo "cannot get node name"
    exit 1
fi

# retrieve golden timestamp from node annotation
golden_timestamp=$($KUBECTL get node ${node_name} -o jsonpath="{.metadata.annotations['kubernetes\.azure\.com/live-patching-golden-timestamp']}")
if [ -z "${golden_timestamp}" ]; then
    echo "golden timestamp is not set, skip live patching"
    exit 0
fi
echo "golden timestamp is: ${golden_timestamp}"

current_timestamp=$($KUBECTL get node ${node_name} -o jsonpath="{.metadata.annotations['kubernetes\.azure\.com/live-patching-current-timestamp']}")
if [ -n "${current_timestamp}" ]; then
    echo "current timestamp is: ${current_timestamp}"

    if [[ "${golden_timestamp}" == "${current_timestamp}" ]]; then
        echo "golden and current timestamp is the same, nothing to patch"
        exit 0
    fi
fi

old_source_list=$(cat ${source_list_path})
# upgrade from base image to a timestamp
# e.g. replace https://snapshot.ubuntu.com/ubuntu/ with https://snapshot.ubuntu.com/ubuntu/20230727T000000Z
sed -i 's/http:\/\/azure.archive.ubuntu.com\/ubuntu\//https:\/\/snapshot.ubuntu.com\/ubuntu\/'"${golden_timestamp}"'/g' ${source_list_path}
# upgrade from one timestamp to another timestamp
sed -i 's/https:\/\/snapshot.ubuntu.com\/ubuntu\/\([0-9]\{8\}T[0-9]\{6\}Z\)/https:\/\/snapshot.ubuntu.com\/ubuntu\/'"${golden_timestamp}"'/g' ${source_list_path}

new_source_list=$(cat ${source_list_path})
if [[ "${old_source_list}" != "${new_source_list}" ]]; then
    # save old sources.list
	echo "$old_source_list" > ${source_list_backup_path}
	echo "/etc/apt/sources.list is updated:"
	diff ${source_list_backup_path} ${source_list_path}
fi

apt_get_update
apt_get_upgrade

# update current timestamp
$KUBECTL patch node ${node_name} -p '{"metadata":{"annotations":{"kubernetes.azure.com/live-patching-current-timestamp":"'"${golden_timestamp}"'"}}}'

echo live patching completed successfully
