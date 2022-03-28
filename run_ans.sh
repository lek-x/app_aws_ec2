#!/bin/bash
ansible-playbook -i  kubespray/inventory/mycluster/hosts.yaml  --become --become-user=root kubespray/cluster.yml --private-key /root/.ssh/storemez_pv





