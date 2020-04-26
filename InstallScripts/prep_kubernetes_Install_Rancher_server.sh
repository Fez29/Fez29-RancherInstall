
#   NOTE

#   Remove Windows Line endings:
#   sed -i -e 's/\r$//' create_mgw_3shelf_6xIPNI1P.sh

# To Be Tested Completely

### CENTOS 7 kubernetes pre-requisites script

# Installing needed packages

#variables

kubernetesRepoFile="[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg"

kubeletConf="vm.overcommit_memory=1
vm.panic_on_oom=0
kernel.panic=10
kernel.panic_on_oops=1
kernel.keys.root_maxkeys=1000000
kernel.keys.root_maxbytes=25000000"

yumProxyConf="[main]
cachedir=/var/cache/yum/$basearch/$releasever
keepcache=0
debuglevel=2
logfile=/var/log/yum.log
exactarch=1
obsoletes=1
gpgcheck=1
plugins=1
installonly_limit=5
bugtracker_url=http://bugs.centos.org/set_project.php?project_id=23&ref=http://bugs.centos.org/bug_report_page.php?category=yum
distroverpkg=centos-release
proxy=http://10.100.26.34:8080
proxy_username=PROXY_USERNAME
proxy_password=PROXY_PASSWORD

#  This is the default, if you make this bigger yum won't see if the metadata
# is newer on the remote and so you'll "gain" the bandwidth of not having to
# download the new metadata and "pay" for it by yum not having correct
# information.
#  It is esp. important, to have correct metadata, for distributions like
# Fedora which don't keep old packages around. If you don't like this checking
# interupting your command line usage, it's much better to have something
# manually check the metadata once an hour (yum-updatesd will do this).
# metadata_expire=90m

# PUT YOUR REPOS HERE OR IN separate files named file.repo
# in /etc/yum.repos.d"

##Choose OS

function getLinuxOS {
    hostnamectl | grep -oP "Operating System:\s+\K\w+"
}

function setHostOs {
    LinuxOsVersion=$(getLinuxOS)
    echo "LinuxOsVersion: $LinuxOsVersion"
    case $LinuxOsVersion in
        *CentOS*)
        linuxOs=$(echo "centos")
        ;;
        *Debian*)
        linuxOs=$(echo "debian")
        ;;
        *Ubuntu*)
        linuxOs=$(echo "ubuntu")
        ;;
    esac
    echo "linuxOs: $linuxOs setHostOs"
}

function installDockerPerLinuxOS {
    echo "linuxOs: $linuxOs function installDockerPerLinuxOS"
    case $linuxOs in
        *centos*)
        installDockerCentOS
        ;;
        *debian* | *ubuntu*)
        installDockerDebian
        ;;
    esac
}

function executeInstallPackages {
    case $linuxOs in
        *centos*)
        installCentosPackages
        ;;
        *debian* | *ubuntu*)
        installDebianPackages
        ;;
    esac
}

function requestActionsToBePerformed {
    rancherOptions=$(whiptail --title "Menu example" --menu "Choose an option" 25 110 16 \
        "<-- Back" "Return to the main menu." \
        "Prepare for Rancher UI/Server" "Prepare Node for Rancher Server/UI" \
        "Install Rancher Server" "Kubernetes Cluster is Active - Want to install Rancher Server" \
        "Create container Node" "Prepare node for additional Kubernetes cluster (Container/services) cluster" \
        "Install Docker Only" "Install Docker only" 3>&1 1>&2 2>&3)

        choice2=$(printf "$rancherOptions" | awk 'FNR == 1 {print}')
        echo "$choice2"
}

choice1=$(requestActionsToBePerformed)

function installCentosPackages {
    sudo yum install curl wget firewalld whiptail -y
}

function installDebianPackages {
    echo "Update Packages"
    sudo apt update && sudo apt install curl wget ufw whiptail -y
}

function createUsers {
    createEtcdUser=$(sudo useradd etcd -u 1500)
    createRancherUser=$(sudo useradd rancher -u 1501)
}

function addSshAuth {
    checkIfSshPublicKeyExists=$(cat ~/.ssh/id_rsa.pub)
    if [[ $checkIfSshPublicKeyExists ]]
    then
        echo "SSH key exists"
    else
        echo "SSH key does not exist, please create 1 and ensure best practices are followed, once done please rerun script"
        #   To be Tested
        #   createSshKey=$(ssh-keygen -t rsa -b 4096)
        #   targetMachine=$(whiptail --inputbox "Enter Target Machine to copy SSH key to" 8 78 --title "FQDN of Machine" 3>&1 1>&2 2>&3 | awk '{print $0}')
        #   sshCopyId=$(ssh-copy-id $USER@$targetMachine)
        exit
    fi
    echo "to be added"
}

function testSshConnection {
    # TO DO
    echo "to be added"
}

function setupPackageManagerProxyAccess {
    if [ "$linuxOs" == "centos" ]
    then
        echo "Backing up /etc/yum.conf to /etc/yum.conf_bak"
        backupYumConf=$(sudo cp /etc/yum.conf /etc/yum.conf_bak)
        requestProxyUserNameCred=$(whiptail --inputbox "Enter your Network Username" 8 78 $USER --title "User Name with no domain" 3>&1 1>&2 2>&3)
        requestProxyPasswordCred=$(whiptail --passwordbox "Enter your password - As is" 8 78 --title "Proxy Server" 3>&1 1>&2 2>&3)
        replaceYumConf=$(sudo cp $yumProxyConf /etc/yum.conf)
        replaceUsernameInYumConf=$(sed -i "s|PROXY_USERNAME|$requestProxyUserNameCred|g" /etc/yum.conf)
        replacePasswordInYumConf=$(sed -i "s|PROXY_USERNAME|$requestProxyPasswordCred|g" /etc/yum.conf)
    else
        echo "To be created and tested"
    fi
}

function checkDockerInstalled {
    isDockerInstalled=$(
        ## Consider Change to Case statement
        if [[ $(which docker) && $(docker --version) ]];
        then
        # echo "Docker is installed"
            if [[ $( docker --version ) == *"19."* || $( docker --version ) == *"17."* ]]; then
                echo "Docker version 19.03!"
            else
                echo "Docker version not 19.03!"
            fi
        else
            echo "Install docker + linuxOs: $linuxOs Function checkDockerInstalled"
            #Check OS version
            installDockerPerLinuxOS
        fi
    )
        addRancherToDockerGroup=$(sudo usermod -aG docker rancher)
        addCurrentUsertoDockerGroup=$(sudo usermod -aG docker $USER)
        echo $isDockerInstalled
}

function setHTTPandHTTPS {
    ## Required for Helm
    ## Look into domain - Is it required?
    defaultProxy="10.100.36.24"
    defaultProxyPort="8080"
    fullDomain=$(whiptail --inputbox "Enter your Network domain in full" 8 78 --title "input domain" 3>&1 1>&2 2>&3 | awk '{print $0}')
    userName=$(whiptail --inputbox "Enter your Network Username" 8 78 $USER --title "User Name with no Domain" 3>&1 1>&2 2>&3| awk '{print $0}')
    password=$(whiptail --passwordbox "Enter your password - If password contains special characters - Use Unicode values instead eg # = %23" 8 78 --title "Proxy Server Password" 3>&1 1>&2 2>&3)
    proxyServer=$(whiptail --inputbox "Enter your Proxy server" 8 78 $defaultProxy --title "Proxy Server" 3>&1 1>&2 2>&3)
    proxyPort=$(whiptail --inputbox "Enter your Proxy server" 8 78 $defaultProxyPort --title "Proxy Server Port" 3>&1 1>&2 2>&3)
    HTTP_PROXY_VALUE="http://${userName}%40${domain}.${domainSuffix}:${password}@${proxyServer}:${proxyPort}"
    export HTTP_PROXY="$HTTP_PROXY_VALUE"
    export HTTPS_PROXY="$HTTP_PROXY_VALUE"
}

function proxySetupRequired {
    proxyRequired=$(
        whiptail --title "Would You Like to configure proxy access" --menu "Choose an option" 25 110 16 \
        "<-- Back" "Return to the main menu." \
        "Yes" "I want to configure credentials for the proxy" \
        "No" "I want to skip this" 3>&1 1>&2 2>&3)

    if [ $proxyRequired == "Yes" ] 
        then 
            setHTTPandHTTPS
        else
            echo "No proxy required"
        fi
}

function testInternetAccess {
    url='https://www.google.com'
    curl=$(curl -Il --write-out "%{http_code}\n" --silent --output /dev/null ${url})
    wget=$(wget --server-response --spider --quiet "${url}" 2>&1 | awk 'NR==1{print $2}')

    if (( $curl != 200 ))
    then
        echo "could not connect!"
    else
        echo "sucessfully tested internet connection"
    fi
}

function open_firewall_ports {
    if [ "$linuxOs" == "centos" ]
    then
        sudo systemctl enable --now firewalld && \
        sudo firewall-cmd --zone=public --permanent --add-port=22/tcp && \
        sudo firewall-cmd --zone=public --permanent --add-port=80/tcp && \
        sudo firewall-cmd --zone=public --permanent --add-port=443/tcp && \
        sudo firewall-cmd --zone=public --permanent --add-port=2376/tcp && \
        sudo firewall-cmd --zone=public --permanent --add-port=2379/tcp && \
        sudo firewall-cmd --zone=public --permanent --add-port=2380/tcp && \
        sudo firewall-cmd --zone=public --permanent --add-port=4001/tcp && \
        sudo firewall-cmd --zone=public --permanent --add-port=6443/tcp && \
        sudo firewall-cmd --zone=public --permanent --add-port=6783-6784/tcp && \
        sudo firewall-cmd --zone=public --permanent --add-port=8472/udp && \
        sudo firewall-cmd --zone=public --permanent --add-port=9099/tcp && \
        sudo firewall-cmd --zone=public --permanent --add-port=10250/tcp && \
        sudo firewall-cmd --zone=public --permanent --add-port=10254/tcp && \
        sudo firewall-cmd --zone=public --permanent --add-port=30000-32767/tcp && \
        sudo firewall-cmd --zone=public --permanent --add-port=30000-32767/udp && \
        sudo firewall-cmd --complete-reload
    elif [ "$linuxOs" == "debian" ] || [ "$linuxOs" == "ubuntu" ]
    then
        # REFERENCE: https://help.replicated.com/community/t/managing-firewalls-with-ufw-on-kubernetes/230
        sudo systemctl enable --now ufw && \
        sudo ufw allow 22/tcp && \
        sudo ufw allow 80/tcp && \
        sudo ufw allow 443/tcp && \
        sudo ufw allow 2376/tcp && \
        sudo ufw allow 2379/tcp && \
        sudo ufw allow 2380/tcp && \
        sudo ufw allow 4001/tcp && \
        sudo ufw allow 6443/tcp && \
        sudo ufw allow 6783:6784/udp && \
        sudo ufw allow 6783/tcp && \
        sudo ufw allow 8472/udp && \
        sudo ufw allow 9099/tcp && \
        sudo ufw allow 10250/tcp && \
        sudo ufw allow 10254/tcp && \
        sudo ufw allow 30000:32767/tcp && \
        sudo ufw allow 30000:32767/udp && \
        sudo ufw allow in on weave from 10.32.0.0/12 && \
        sudo ufw allow out on weave to 10.32.0.0/12 && \
        sudo ufw default allow FORWARD && \
        sudo ufw enable && \
        sudo ufw reload
    else
        echo "OS not configured"
    fi
}

function installKubectl {
    checkIfAlreadyInstalled=$(confirmKubernetesClusterRunning)
    if [[ "$checkIfAlreadyInstalled" ]]
    then
        if [ "$linuxOs" == "centos" ]
            then
                createRepoFile=$(echo "$kubernetesRepoFile" >> ./kubernetes.repo)
                createDir=$(mkdir -p /etc/yum.repos.d)
                moveRepoFile=$(sudo mv ./kubernetes.repo /etc/yum.repos.d/kubernetes.repo)
                installKubectl=$(sudo yum install -y kubectl)
        elif [ "$linuxOs" == "debian" ] || [ "$linuxOs" == "ubuntu" ]
            then
            UpdateAndInstallPackages=$(sudo apt update && sudo apt install -y apt-transport-https gnupg2)
            AddGpg=$(curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -)
            checkIfAptListExists=$(cat /etc/apt/sources.list.d/kubernetes.list)
            if [[ $checkIfAptListExists ]]
            then
                echo "Apt list already exists"           
            else
                AddAptSource=$(echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list)
            fi
            UpdateAndInstallKubectl=$(sudo apt-get update && sudo apt-get install -y kubectl)
        else
            echo "OS not configured"
        fi
    else
        echo "$checkIfAlreadyInstalled"
    fi
}

function sysctl_settings {
    createConfFile=$(echo "$kubeletConf" >> ./90-kubelet.conf)
    moveRepoFile=$(sudo mv ./90-kubelet.conf /etc/sysctl.d/90-kubelet.conf)
    sysctlCmd=$(sudo sysctl -p /etc/sysctl.d/90-kubelet.conf)
    check_completed=$(sudo sysctl vm.overcommit_memory)
    echo "overcommit_memory= if following value: "$check_completed" is equal to 1 operation has been completed"
}

function installRke {
    checkRkeVersion=$(rke -version | awk 'NR==1{print $3}')
    if [ "$checkRkeVersion" == "v1.0.4" ]
    then
        echo "RKE already installed"
    else
        downloadRke=$(wget https://github.com/rancher/rke/releases/download/v1.0.4/rke_linux-amd64)
        renameToRKE=$(mv rke_linux-amd64 rke)
        makeRkeExecutable=$(chmod +x rke)
        moveToRkePath=$(sudo mv rke /usr/bin/)
    fi
}

function installHelm {
    checkIfHelmInstalled=$(helm version)
    if [ "$checkIfHelmInstalled"  ];
    then
        echo "Helm Already Installed: Details: $checkIfHelmInstalled"
    else
        downloadHelm=$(wget https://get.helm.sh/helm-v3.1.2-linux-amd64.tar.gz)
        decompressHelmFile=$(tar -zxvf helm-v3.1.2-linux-amd64.tar.gz)
        moveToHelmPath=$(sudo mv linux-amd64/helm /usr/bin/helm)
    fi
}

function installRancherHelmChart {
    addRancherHelmRepo=$(helm repo add rancher-stable https://releases.rancher.com/server-charts/stable)
    createCattleNamespace=$(kubectl create namespace cattle-system)
}

function chooseSelfSignedCertOrNot {
    function confirmCertManagerDeployment {
    checkForDeployment=$(kubectl get pods --namespace cert-manager | grep "cert" | wc -l)
    checkCertManagerDeployProgress=$(kubectl get pods --namespace cert-manager | grep "1/1" | wc -l)
    checkCertManagerDeployForCrash=$(kubectl get pods --namespace cert-manager | grep "CrashLoopBackOff" | wc -l)
    if [[ $checkForDeployment ]] && (( "$checkForDeployment" == "0" ));
    then
        echo "Cert Manager not deployed"
    else
        if (( "$checkCertManagerDeployProgress" < 3 )) && (( "$checkCertManagerDeployForCrash" == 0 ));
        then
            sleep 30 && echo "Confirming deployment again"
            confirmCertManagerDeployment
        elif (( "$checkCertManagerDeployForCrash" != 0 ));
            then 
                echo "Check deployment for issues"
        else
            echo "Deployed sucessfully"
        fi
    fi
}
    alreadyDeployed=$(confirmCertManagerDeployment)
    if [ "$alreadyDeployed" == "Cert Manager not deployed" ];
    then
        echo "Ensure kubectl commands work otherwise below will fail"

        certChoice=$(whiptail --title "Choose what you would like to do:" --checklist --separate-output --cancel-button Cancel "Choose an option" 25 78 16 \
            "Use Self-Signed Certificates" "" on  \
            "Use certificates from files" "" off 3>&1 1>&2 2>&3)

        certChoice1=`printf "$certChoice" | awk 'FNR == 1 {print}'`
        certChoice2=`printf "$certChoice" | awk 'FNR == 2 {print}'`

        if [ "Use Self-Signed Certificates" == "$certChoice1" ];
        then
            certManagerManifest="https://raw.githubusercontent.com/jetstack/cert-manager/release-0.12/deploy/manifests/00-crds.yaml"
            customResourceDefinition=$(kubectl apply --validate=false -f $certManagerManifest)
            createCertManagerNamespace=$(kubectl create namespace cert-manager)
            addJetstackHelmRepo=$(helm repo add jetstack https://charts.jetstack.io)
            updateHelmRepo=$(helm repo update)
            installCertManagerHelmChart=$(helm install cert-manager jetstack/cert-manager --namespace cert-manager --version v0.12.0)
            confirmCertManagerDeployment
            ### How to delete
            # kubectl delete -f $certManagerManifest
        else
            echo "Refer to https://rancher.com/docs/rancher/v2.x/en/installation/k8s-install/helm-rancher/#install-rancher-with-helm-and-your-chosen-certificate-option"
            exit
        fi
    else
        echo "Check deployment for issues"
    fi
}

function installRancherUI {
    function confirmRancherDeployment {
        checkRancherDeploymentForCrash=$(kubectl get pods --namespace cattle-system | grep "CrashLoopBackOff" | wc -l)
        checkRancherDeploymentProgress=$(kubectl get pods --namespace cattle-system | grep "1/1" | wc -l)

        if (( "$checkRancherDeploymentProgress" == 3 ));
            then
                echo "$confirmRancherDeploymentComplete"
                echo "Deployment Completed Successfully"
        elif (( "$checkRancherDeploymentProgress" < 3 )) && (( "$checkRancherDeploymentForCrash" < 1 ));
            then
                echo "$confirmRancherDeploymentComplete"
                echo "Check Status of Deployment again"
                sleep 30 && confirmRancherDeployment
        else
            echo "Check deployment for issues"
        fi
    }
    RancherUiClusterHostname=$(whiptail --inputbox "Server Name or Clustered Link" 8 78 --title "Enter name of Rancher UI/server Cluster" 3>&1 1>&2 2>&3 | awk '{print $0}')
    RancherLocalCluster=$(whiptail --title "Allow Local Kubernetes Cluster for Rancher" --menu "Choose an option" 25 110 16 \
        "<-- Back" "Return to the main menu." \
        "" "Yes" \
        "" "No"  3>&1 1>&2 2>&3)
    if [ "$RancherLocalCluster" == "Yes" ];
    then
        installRancherthroughHelmChart=$(helm install rancher rancher-stable/rancher --namespace cattle-system --set hostname=$RancherUiClusterHostname --set addLocal="false" --set useBundledSystemChart=true)
    else
        installRancherthroughHelmChart=$(helm install rancher rancher-stable/rancher --namespace cattle-system --set hostname=$RancherUiClusterHostname --set useBundledSystemChart=true)
    fi
    ## Confirm if below works with script
    #checkRancherDeploymentStatus=$(kubectl -n cattle-system rollout status deploy/rancher)
    confirmRancherDeployment
}

function installDockerCentOS {
    installCentosPackages
        removeOldVersions=$(sudo yum remove -y docker \
                docker-client \
                docker-client-latest \
                docker-common \
                docker-latest \
                docker-latest-logrotate \
                docker-logrotate \
                docker-engine)

        installDockerPrerequisites=$(sudo yum install -y yum-utils \
                device-mapper-persistent-data \
                lvm2)

        setupDockerRepo=$(sudo yum-config-manager \
                --add-repo \
                https://download.docker.com/linux/centos/docker-ce.repo)

        installDocker=$(sudo yum install -y docker-ce docker-ce-cli containerd.io)

        enableDocker=$(sudo systemctl enable --now docker.service)
        # Confirm SuccessFull Install
        checkDockerInstalled
}

function installDockerDebian {
    installDebianPackages
        ## Different fom CentOS
        removeOldVersions=$(sudo apt remove -y docker \
                docker-engine \
                docker.io \
                containerd \
                runc)

        ## Different fom CentOS
        installDockerPrerequisites=$(sudo apt-get install -y \
                apt-transport-https \
                ca-certificates \
                curl \
                gnupg2 \
                software-properties-common)

        addKey=$(curl -fsSL https://download.docker.com/linux/$linuxOs/gpg | sudo apt-key add -)

        ## Different fom CentOS
        setupDockerRepo=$(sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$linuxOs $(lsb_release -cs) stable")
        
        installDocker=$(sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io)

        ## Same exactly
        enableDocker=$(sudo systemctl enable --now docker.service)
        # Confirm SuccessFull Install
        checkDockerInstalled
}

#Work on converting above two similair function to a case statement

function installDockerCaseStatement {
    installCentosPackages
        removeOldVersions=$(sudo yum remove -y docker \
                docker-client \
                docker-client-latest \
                docker-common \
                docker-latest \
                docker-latest-logrotate \
                docker-logrotate \
                docker-engine)

        installDockerPrerequisites=$(sudo yum install -y yum-utils \
                device-mapper-persistent-data \
                lvm2)

        setupDockerRepo=$(sudo yum-config-manager \
                --add-repo \
                https://download.docker.com/linux/centos/docker-ce.repo)

        installDocker=$(sudo apt update && sudo yum install -y docker-ce docker-ce-cli containerd.io)

        enableDocker=$(sudo systemctl enable --now docker.service)
}

function chooseSupportedKubernetesVersion {
    checkRkeVersion=$(rke -version | awk 'NR==1{print $3}')

    case $checkRkeVersion in
        "v1.0.4")
        echo -n "v1.16.6-rancher1-2"
        ;;
        "v1.0.3")
        echo -n "v1.16.6-rancher1-1"
        ;;
        "v1.0.2")
        echo -n "v1.16.4-rancher1-1"
        ;;
        "v1.0.1")
        echo -n "v1.16.4-rancher1-1"
        ;;
        "v1.0.0")
        echo -n "v1.16.3-rancher1-1"
        ;;
    esac
}

function checkEtcdUserValues {
    etcdUidValue=$(id etcd -u)
    etcdGidValue=$(id etcd -g)
}

function buildKubernetesClusterFileV1AndStartKubernetes {
    checkIfKubernetesAlreadyRunning=$(confirmKubernetesClusterRunning)
    if [[ "$checkIfKubernetesAlreadyRunning" == "Kubernetes Cluster active" ]]
    then
        echo "Kubernetes Cluster already active"
    else
        echo "Ensure user that is executing this script is user to be used to run Kubernetes cluster"
        template_kubernetes_user=$USER
        prepareNodeForSudoless=$(sudo usermod -aG docker $template_kubernetes_user)
        getRkeVersion=$(chooseSupportedKubernetesVersion)
        echo "Ensure you are running from Directory that script is place in if is failing"
        createCopyOfTemplate=$(cp ../Templates/rancher-cluster-basic.yaml $(pwd)/rancher-cluster.yaml)
        hostnamesReplace=$(sed -i "s|HOSTNAME_REPLACE|$HOSTNAME|g" $(pwd)/rancher-cluster.yaml)
        kubernetesVersionVariableReplace=$(sed -i "s|kubernetes_version_variable|$getRkeVersion|g" $(pwd)/rancher-cluster.yaml)
        etcdUserVariableReplace=$(sed -i "s|etcd_user_var|$etcdUidValue|g" $(pwd)/rancher-cluster.yaml)
        etcdGroupVariableReplace=$(sed -i "s|etcd_group_var|$etcdGidValue|g" $(pwd)/rancher-cluster.yaml)
        replaceUserInTemplate=$(sed -i "s|kubernetes_user|$template_kubernetes_user|g" $(pwd)/rancher-cluster.yaml)
        startKubernetesCluster=$(rke up --config $(pwd)/rancher-cluster.yaml)
        setupKubectl=$(mkdir -p /home/$template_kubernetes_user/.kube && cp $(pwd)/kube_config_rancher-cluster.* /home/$template_kubernetes_user/.kube/config)
    fi
}

function confirmKubernetesClusterRunning {
    getKubectlNodes=$(kubectl get nodes)
    getAllKubectlNamespaces=$(kubectl get pods --all-namespaces)
    if [[ $getKubectlNodes ]] && [[ $getAllKubectlNamespaces ]]
    then
        echo "Kubernetes Cluster active"
    else
        echo "Check for issues with deployment"
    fi
}

function executeRkeClusterInstall {
    # TO DO add documentation on how to
    addSshAuth
    # TO DO
    testSshConnection
    buildKubernetesClusterFileV1AndStartKubernetes
    confirmKubernetesClusterRunning
}

function prepareNodeForRancherServer {
    checkIfKubernetesClusterAlreadyRunning_var=$(confirmKubernetesClusterRunning)
    if [ "$checkIfKubernetesClusterAlreadyRunning_var" == "Kubernetes Cluster active" ]
    then
        echo "$checkIfKubernetesClusterAlreadyRunning_var"
    else
        ## This executes all functions required to prep a Rancher Server Node
        setupPackageManagerProxyAccess
        executeInstallPackages
        createUsers
        checkEtcdUserValues
        proxySetupRequired
        testInternetAccess
        open_firewall_ports
        installKubectl
        installHelm
        sysctl_settings
        installRke
        checkDockerInstalled
        executeRkeClusterInstall
    fi
}

function installRancherServer {
    executeInstallPackages
    ## This executes all functions required to install Rancher Server on a Node
    buildKubernetesClusterFileV1AndStartKubernetes
    proxySetupRequired
    installRancherHelmChart
    chooseSelfSignedCertOrNot
    installRancherUI
}

### Get node ready for COntainer CLuster Deployment

function prepareClusterNode {
    setupPackageManagerProxyAccess
    proxySetupRequired
    executeInstallPackages
    open_firewall_ports
    sysctl_settings
    checkDockerInstalled
}

case $choice1 in
	"Prepare for Rancher UI/Server")
        setHostOs
		prepareNodeForRancherServer
		;;
	"Install Rancher Server")
        setHostOs
		installRancherServer
		;;
	"Create container Node")
        setHostOs
		prepareClusterNode
		;;
    "Install Docker Only")
        echo "Case Statement"
        setHostOs
        installDebianPackages
		checkDockerInstalled
		;;
esac

errorCode=$?
if [ $errorCode -ne 0 ]; then
  echo "We have an error"
  echo $errorCode
fi