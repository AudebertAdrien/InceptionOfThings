# IoT

## The goal

Understand & setup Kubernet with firstly Vagrant to deploy it in a Virtual Machine. And secondly configure a kubernet cluster with automated synchronization thank to argocd.

## Requirement

For the first & seconde part, you need to install virtual box and vagrant to execute vagrant files.

For the third part & bonuses, you have to install docker & k3d on your computer to execute kubectl command and, for bonuses, also helm package, you can execute `instal.sh` in `scripts/` directory.


## Execution

#### Part 1 Guide :
1. Have to create the `confs/` directory for vagrant 
````sh
mkdir confs
````
2. Just execute the vagrant file in the `p1/` directory
````sh
vagrant up
````
3. Connect in ssh to the server VM
sh````
vagrant ssh lle-saulS
````
4. Verify if Agent cluster work fine
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
````

#### Part 3 Guide : 
1. If you d'ont a have all the dependency such as docker or kubernet, execute the `install.sh`
````sh
bash ./scripts/install.sh
````
2. Execute the script for configure the cluster
````sh
bash ./scripts/start_cluster.sh
````
At the end of the script you can see the admin password for the argocd interface
3. In your `host` file you need to add this entries
````sh
127.0.0.1 argocd.local
127.0.0.1 dev.local
````
4. You can test to connect to argocd interface (only on http) on the 8000 port or on the dev app
````sh
http://argocd.local:8000/
````

## Bonuses

For this bonus, you need to get one more dependency on your computer : HELM, you can execute `scripts/install.sh` to install it.
**With Gitlab, this k3d cluster is very heavy in ressources, make sure docker are at least 6Go of RAM**

1. You can execute the usual script to start the k3d cluster
````sh
bash ./scripts/start_cluster.sh
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
````
**The admin password for gitlab & argocd can be obtain by executing `scripts/start_cluster.sh`**
4. On Gitlab interface, you can create a repository, if you name it `iot`, you can automatly deploy it in argocd with this command :
````sh`
sudo kubectl -n argocd -f apply ./confs/config.app.yaml
````