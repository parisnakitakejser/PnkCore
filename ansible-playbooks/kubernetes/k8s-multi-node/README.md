# Kubernetes Multi Node

Required 2 VMs with 2gb memory, 2 vCPU and 50gb+ disk

Tested on Ubuntu Server 24.04 LTS inside VirtualBox

You can easily enable your user to no longer use a password with this line!

```
echo "$USER ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$USER
```

Go ahead and add k8s-single-node to your host file, and then point it to your virtual machine's IP address, and you're all set!

Prepare all your instances for Kubernetes

``` bash
ansible-playbook -i inventories/development/hosts.yaml plays/prepare-instances/playbook.yaml
```

Now to run controlplane setup to be ready for controlplane.

``` bash
ansible-playbook -i inventories/development/hosts.yaml plays/install-controlplane/playbook.yaml
```

Now you have both token and hash from the output, copy that into the vars and change the rest of the settings to match your controlplane vm and run the worker node setup playbook.

``` bash
ansible-playbook -i inventories/development/hosts.yaml plays/install-workernode/playbook.yaml
```

## Be social with me! :)
- X: https://x.com/parisnkejser
- LinkedIn: https://www.linkedin.com/in/parisnakitakejser/
- GitHub: https://github.com/parisnakitakejser
- YouTube: https://www.youtube.com/c/parisnakitakejser?sub_confirmation=1