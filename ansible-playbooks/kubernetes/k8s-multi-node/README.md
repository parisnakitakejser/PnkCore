# Kubernetes Multi Node

Required 2 VMs with 2gb memory, 2 vCPU and 50gb+ disk

Tested on Ubuntu Server 24.04 LTS inside VirtualBox

You can easily enable your user to no longer use a password with this line!

```
echo "$USER ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$USER
```

Go ahead and add both vm instance to your host file `k8s-multi-node-cp` for controlplane node and `k8s-multi-node-worker` for workernode where you are good!

Before running ansible playbook you shoud change the ip address for your controlplanene server, this can be changed in `inventories/development/group_vars.yml` after that you can execute the ansible playbook command.

``` bash
ansible-playbook -i inventories/development/hosts.yaml playbook.yaml
```


## Be social with me! :)
- X: https://x.com/parisnkejser
- LinkedIn: https://www.linkedin.com/in/parisnakitakejser/
- GitHub: https://github.com/parisnakitakejser
- YouTube: https://www.youtube.com/c/parisnakitakejser?sub_confirmation=1