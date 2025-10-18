#!/bin/bash
set -e

# --- Configuration ---
NODES_TO_UPGRADE="192.168.0.205 192.168.0.206 192.168.0.207"
UPGRADE_IMAGE="factory.talos.dev/nocloud-installer/613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245:v1.11.1"
TARGET_VERSION="v1.11.1"

# --- Upgrade Loop ---
echo "Starting ROLLING-DRAIN upgrade of worker nodes..."

for node_ip in $NODES_TO_UPGRADE; do
    echo "============================================================"
    echo "Processing upgrade for node: ${node_ip}"
    echo "============================================================"

    # 1. DRAIN the node to safely evict pods
    # --ignore-daemonsets is crucial because DaemonSet pods can't be evicted.
    # --delete-emptydir-data is needed for pods that use emptyDir volumes.
    echo "🔹 Draining node ${node_ip}..."
    if ! kubectl drain ${node_ip} --ignore-daemonsets --delete-emptydir-data --force; then
        echo "❌ Drain failed for node ${node_ip}. Aborting script."
        # Attempt to uncordon the node before exiting so it's not left in a bad state
        kubectl uncordon ${node_ip}
        exit 1
    fi
    echo "Drain complete."

    # 2. UPGRADE the node using talosctl
    echo "🔹 Upgrading node ${node_ip}..."
    talosctl upgrade --preserve --image ${UPGRADE_IMAGE} --nodes=${node_ip}
    echo "Upgrade command sent. Waiting for node to reboot and rejoin..."

    # 3. WAIT for the node to become Ready in Kubernetes
    echo "🔹 Waiting for node to become Ready in Kubernetes..."
    kubectl wait --for=condition=Ready node/${node_ip} --timeout=10m
    echo "Node ${node_ip} is Ready."

    # 4. VERIFY the Talos version as a final check
    echo "🔹 Verifying Talos version..."
    current_version=$(talosctl get members -o jsonpath="{.items[?(@.hostname=='${node_ip}')].talosVersion}")
    if [[ "${current_version}" != "${TARGET_VERSION}" ]]; then
        echo "❌ Version mismatch on node ${node_ip}! Expected ${TARGET_VERSION} but found ${current_version}."
        echo "Node will be left cordoned for manual inspection."
        exit 1
    fi
    echo "Talos version ${current_version} verified."

    # 5. UNCORDON the node to allow new pods to be scheduled on it
    echo "🔹 Uncordoning node ${node_ip}..."
    kubectl uncordon ${node_ip}
    echo "Uncordon complete."

    echo "✅ Node ${node_ip} upgrade finished."
    
    echo "Pausing for 30 seconds before starting the next node..."
    sleep 30
done

echo "🎉 All specified worker nodes have been upgraded successfully."
