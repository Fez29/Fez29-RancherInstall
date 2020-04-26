# RancherInstall

This script was created to automate the installation of the Kubernetes cluster and to start the Racher Server for you as well.
At this time it workes for a single machine.

Notes:

Currently the ssh requirements have been neglected so the SSH key needs to be created and a ssh-copy-id should be done with the user that the script will be run as, to the local machine.

Usage:
Once the above is done.
Clone the repo into your desired location:

````
cd RancherInstall/InstallScripts
````
Make the script executable.
````
chmod +x prep_kubernetes_Install_Rancher_server
````
Execute the script. Choose Option 1 to begin with. Select your desired options, select no on the Proxy prompts if you are NOT behind a corporate proxy and authentication is requried by the proxy.

Once done.

Execute the script again and select the RancherUI option.

Select the prompts again according to you requirements, you will be prompted if you want to "Allow Local Kubernetes Cluster for Rancher", this means you will have a cluster available in Rancher for the machine you are executing the script on.

At this time the template selected for use in the Kubernetes cluster is not a Production ready version but rather more suitable for testing on a smaller architecture.