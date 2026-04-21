# IoT

## The goal

Understand and set up Kubernetes. First, use Vagrant to deploy it within a Virtual Machine. Second, configure a Kubernetes cluster with automated synchronization using Argo CD.

## Requirement

* **For Parts 1 & 2:** You need to install VirtualBox and Vagrant on your host machine to execute the Vagrantfiles.
* **For Part 3 & Bonus:** You must have Docker and K3d installed on your computer to use the `kubectl` command. For the bonus, you will also need the Helm package manager. You can easily install these dependencies by executing the `install.sh` script located in the `scripts/` directory.

## Execution

#### Part 1 Guide :
1. Run the Vagrantfile in the `p1/` directory:
````sh
vagrant up
````
2. Connect via SSH to the server VM:
````sh
vagrant ssh aaudeberS
````
3. Verify that the cluster nodes are running properly:
````sh
sudo kubectl get nodes
````

#### Part 2 Guide :
1. Run the Vagrantfile in the `p2/` directory:
````sh
vagrant up
````
2. Add the following entries to your host machine's hosts file `(/etc/hosts)`:
````sh
192.168.56.110 app1.com
192.168.56.110 app2.com
192.168.56.110 app3.com
````
3. Once all applications are ready within the VM, you can test the ingress routes:
````sh
http://app1.com/
http://app2.com/
http://192.168.56.110/
````

#### Part 3 Guide : 
1. Run the Vagrantfile in the `p3/` directory:
````sh
vagrant up
````
Note: At the end of the provisioning script, the `admin` password for the `Argo CD` interface will be displayed in your terminal.
2. Add the following entries to your host machine's hosts file `(/etc/hosts)`:
````sh
127.0.0.1 argocd.local
127.0.0.1 dev.local
````
3. You can now access the Argo CD interface and the deployed app (HTTP only) via port 8000:
````sh
http://argocd.local:8000/
http://dev.local:8000/
````

## Bonuses

**WARNING: GitLab makes this K3d cluster extremely resource-intensive. Ensure your computer as at least 6GB of RAM free of RAM.**

1. You can execute the vagrant file in the `bonus/` directory
````sh
vagrant up
````
Note: Because GitLab requires significant resources and performs database migrations on its first run, it will take a long time to start. Please be patient.
2. Add the following entries to your host machine's hosts file `(/etc/hosts)`:
````sh
127.0.0.1 gitlab.local
127.0.0.1 argocd.local
127.0.0.1 dev.local
````
3. You can access all interfaces using these hostnames on port 8000:
````sh
http://gitlab.local:8000/
http://argocd.local:8000/
http://dev.local:8000/
````
**The admin passwords for GitLab and Argo CD are displayed at the end of the installation script.** You can also retrieve them at any time by executing: 
````sh
scripts/get_password.sh
````
For the `Argo CD` Web Interface, the admin username is `admin`.
For the `GitLab` Web Interface, the admin username is `root`.

The target repository and access tokens are automatically created and pushed by the installation script.