#!/bin/bash

# List of VM IDs to destroy
VM_IDS=("100" "101")

for VM_ID in "${VM_IDS[@]}"; do
  # Check if the VM exists
  if qm status "${VM_ID}" >/dev/null 2>&1; then
    echo "Stopping VM ${VM_ID}..."
    qm stop "${VM_ID}" >/dev/null 2>&1

    echo "Destroying VM ${VM_ID}..."
    qm destroy "${VM_ID}" --purge >/dev/null 2>&1

    echo "VM ${VM_ID} has been destroyed successfully!"
  else
    echo "VM ${VM_ID} does not exist. Skipping..."
  fi
done