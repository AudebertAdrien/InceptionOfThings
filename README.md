# IoT

## The goal

Understand & setup Kubernet with firstly Vagrant to deploy it in a Virtual Machine. And secondly configure a kubernet cluster with automated synchronization thank to argocd.

## Requirement

For the first & seconde part, you need to install virtual box and vagrant to execute vagrant files.

For the third part & bonuses, you have to install docker & k3d on your computer to execute kubectl command and, for bonuses, also helm package, you can execute `instal.sh` in `scripts/` directory.


## Execution

#### Part 1 Guide :
1. Just execute the vagrant file in the `p1/` directory
````sh
vagrant up
````
2. Connect in ssh to the server VM
sh````
vagrant ssh aaudeberS
````
3. Verify if Agent cluster work fine
sh````
sudo kubectl get nodes
````

#### Part 2 Guide :
1. You can execute the vagrant file in the `p2/` directory
````sh
vagrant up
````
2. In your host file you have to add this entries :
````sh
192.168.56.110 app1.com
192.168.56.110 app2.com
192.168.56.110 app3.com
````
3. When all app are ready in the VM you can test the ingress with every host
````sh
http://app1.com/
http://app2.com/
http://192.168.56.110/
````

#### Part 3 Guide : 
1. You can execute the vagrant file in the `p3/` directory
````sh
vagrant up
````
At the end of the script you can see the admin password for the argocd interface
2. In your `host` file you need to add this entries
````sh
127.0.0.1 argocd.local
127.0.0.1 dev.local
````
3. You can test to connect to argocd interface (only on http) on the 8000 port or on the dev app
````sh
http://argocd.local:8000/
http://dev.local:8000/
````

## Bonuses

**With Gitlab, this k3d cluster is very heavy in ressources, make sure the VM has at least 6Go of RAM**

1. You can execute the vagrant file in the `bonus/` directory
````sh
vagrant up
````
Because Gitlab need a lot of ressources, it make a long time to start, so be patient.
2. In your `host` file you need to add this entries
````sh
127.0.0.1 gitlab.local
127.0.0.1 argocd.local
127.0.0.1 dev.local
````
3. You can access to all interface on with this `host` on the 8000 port
````sh
http://gitlab.local:8000/
http://argocd.local:8000/
http://dev.local:8000/
````
**The admin password for gitlab & argocd can be obtain at the end of the install script or by executing `scripts/get_password.sh`**
For the Argocd Web Interface, the admin username is `admin`.
For the Gitlab Web Interface, the admin username is `root`.

The repository is automaticly created with the installed script.