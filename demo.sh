#!/bin/bash

########################
# include the magic https://github.com/paxtonhare/demo-magic
# demo-magic.sh is a handy shell script that enables you to script repeatable demos
# in a bash environment so you don't have to type as you present. Rather than trying 
# to type commands when presenting you simply script them and let demo-magic.sh run 
# them for you.
########################
if [ ! -f "./demo-magic.sh" ]; then
  wget -O demo-magic.sh https://raw.githubusercontent.com/paxtonhare/demo-magic/master/demo-magic.sh
fi
# shellcheck disable=SC1091
. demo-magic.sh -n "$@"
. config.ini
#echo AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID
#echo AWS_REGION=$AWS_REGION
#p "#Press if you can see AWS_ACCOUNT_ID and AWS_REGION have been set correctly"
#wait
#: ${DEMO:=basic}
DEMO=$1

export TYPE_SPEED=50
#Modify BASE_DIR to your dem base directory

#clear
#p "# Press enter to start the $DEMO."
#wait


Create_ECR_Repo () {
  # If the repository doesn't exist in ECR, create it.
  if [ $# -eq 0 ] 
  then 
    p "Please provide the container image name of the AWS ECR repositiory"
    exit 255
  else 
    image=$1
  fi
  aws ecr describe-repositories --repository-names "${image}" > /dev/null 2>&1

  if [ $? -ne 0 ]
  then
      p "aws ecr create-repository --repository-name \"${image}\""
      aws ecr create-repository --repository-name "${image}" > /dev/null
  fi

  cat <<EOF
Build your Docker image using the following command. For information on building a Docker file from scratch see the instructions here . You can skip this step if your image is already built:
docker build -t ${image} .

After the build completes, tag your image so you can push the image to this repository:
docker tag ${image}:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${image}:latest

Run the following command to push this image to your newly created AWS repository:
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${image}:latest
EOF
}

Login_ECR () {
  # Get the login command from ECR and execute it directly
  aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}".dkr.ecr."${AWS_REGION}".amazonaws.com
}

Clone_Juice-Shop_Repo () {
  p "Clone the Juice-Shop repo:"
  pe "cd $BASE_DIR"
  pe "git clone https://github.com/bkimminich/juice-shop.git"
}

Clone_Kubernetes_Ingress_Repo () {
  p "Clone the Ingress controller repo:"
  pe "cd $BASE_DIR"
  pe "git clone https://github.com/nginxinc/kubernetes-ingress"
  pe "cd $BASE_DIR/kubernetes-ingress"
  p "Check the latest stable release, please update the version v1.8.1 if a newer version is released"
  pe "git checkout v1.8.1"
  pe "git status"
  p "You can find the doucment of Building the Ingress Controller Image at https://docs.nginx.com/nginx-ingress-controller/installation/building-ingress-controller-image/"
  p "Copy the NGINX Plus/App Protect license files (nginx-repo.crt and nginx-repo.key) to $BASE_DIR/kubernetes-ingress."
  p "You can send a request for NGINX Plus and NGINX App Protect trial license at https://www.nginx.com/free-trial-request/."
  p "#Press Enter if you copy the license files nginx-repo.crt and nginx-repo.key to the $BASE_DIR/kubernetes-ingress directory and the version is v1.8.1."
  wait
}
Build_Push_Juice-Shop_Image () {
    Clone_Juice-Shop_Repo
    Create_ECR_Repo $JUICE_SHOP_IMAGE
    Login_ECR 
    pe "cd $JUICE_SHOP_BASE_DIR"
    #fullname="${account}.dkr.ecr.${AWS_REGION}.amazonaws.com/${image}:latest"
    fullname="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${JUICE_SHOP_IMAGE}" 
    p "Build Juice-Shop container image" 
    pe "docker build -t ${image} ."
    p "tag the juice-shop container image so we can push the image to this repository:"
    pe "docker tag ${image}:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${image}:latest"
    p "Push the Juice-Shop container image to the newly created AWS repository:"
    pe "docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${image}:latest"
}
Build_Push_IC_AppProtect_Image () {
    Clone_Kubernetes_Ingress_Repo
    Create_ECR_Repo $INGRESS_IMAGE
    Login_ECR 

    pe "cd $INGRESS_BASE_DIR"
    #fullname="${account}.dkr.ecr.${AWS_REGION}.amazonaws.com/${image}:latest"
    fullname="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${INGRESS_IMAGE}"

    # Build the docker image locally with the image name and then push it to ECR
    # with the full name.

    pe "make DOCKERFILE=appprotect/DockerfileWithAppProtectForPlus PREFIX=${fullname}"

}
Create_Ec2_Key_Pair () {
  p "create ec2 key pair devsecops and save it to ~/.ssh/devsecops.pem"
  p "#Press to continue"
  wait
  clear
  p
  if [ -f ~/.ssh/devsecops.pem ]; then
    p "\~/.ssh/devsecops.pem exists, delete this file"
    pe "sudo rm ~/.ssh/devsecops.pem"
  fi
  pe "aws ec2 create-key-pair --key-name devsecops --query 'KeyMaterial' --output text > ~/.ssh/devsecops.pem"
  pe "aws ec2 describe-key-pairs --key-name devsecops"
  pe "chmod 400 ~/.ssh/devsecops.pem"
}


Create_EKS_Cluster() {
  p "Start to create EKS cluster"
  p "On AWS, create devsecops user, add it into Admin group; if Admin group doesn't exist, create it, save the access id and key"
  p "Run aws configure to add aws id and key, chose region us-west-2"
  p "#Press to continue"
  wait
  Check_devsecops_User
  p "#Press to continue"
  wait

  read -t 3 -n 1 -p "Create SSH key pair devsecops(y/n)? " answer
  [ -z "$answer" ] && answer="No"  # if 'yes' have to be default choice
  case ${answer:0:1} in
      y|Y )
          Create_Ec2_Key_Pair
      ;;
      * )
          p "not create SSH key pair devsecops"
      ;;
  esac

  p "#Press to continue"
  wait
  pe "eksctl create cluster --name $EKS_CLUSTER_NAME --version 1.17 --region us-west-2 --nodegroup-name linux-nodes \
--nodes 2 --nodes-min 1 --nodes-max 4 --ssh-access --ssh-public-key devsecops --managed"

}
Onboard_NGINX_IC_App_Protect() {
  p "onboard NGINX Plus Ingress Controller with App Protect"
  Login_ECR
  pe "cd $INGRESS_BASE_DIR/deployments/helm-chart/"
  pe "pwd"
  p "#Press Enter if the pwd is helm-chart"
  wait
  fullname="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${INGRESS_IMAGE}"
  pe "helm repo add nginx-stable https://helm.nginx.com/stable"
  pe "helm repo update"
  pe "kubectl create -f crds/"
  pe "helm upgrade -i nginx-controller-nap nginx-stable/nginx-ingress --set controller.image.repository=$fullname --set controller.nginxplus=true --set controller.appprotect.enable=true"
  #pe "helm install my-release -f values-plus.yaml ."
  pe "helm list"
  #After onboarding NGINX Plus Ingress Controller with App Protect, deploy a syslog server to receive the violation event log sent from NGINX App Protect Ingress
  Deploy_Syslog_Server
}


Check_Syslog () {
  syslog_pod=$(kubectl get pod -l app=syslog -o jsonpath='{.items[].metadata.name}')
  pe "kubectl exec -ti $syslog_pod -- cat /var/log/messages"
  p "You can use the following command to log into the syslog container to check the violation event log:"
  p "kubectl exec -ti $syslog_pod -- bash"
  p "The event logs are in the /var/log/messages file."
}
Deploy_Syslog_Server() {
  p "Create the syslog service and pod for the App Protect security logs:"
  pe "kubectl create -f $INGRESS_BASE_DIR/examples/appprotect/syslog.yaml"
  
}
Deploy_Juice-Shop_Without_App_Protect () {
  pe "cd $DEMO_SHELL_BASE_DIR"
  pe "helm upgrade -i juice-shop juice-shop-chart --set ingress.app_protect.enabled=false"
  #INGRESS_HOSTNAME=$(kubectl get ingress -o jsonpath='{.items[].status.loadBalancer.ingress[].hostname}')
  INGRESS_HOSTNAME=$(kubectl  get svc nginx-controller-nap-nginx-ingress -o jsonpath='{.status.loadBalancer.ingress[].hostname}')

  p "Ingress hostname is $INGRESS_HOSTNAME, update .Values.ingress.hosts.host in the values.yaml to match this hostname"
  grep "\- host:" juice-shop-chart/values.yaml
  sed -i '' -E 's/- host: .*/- host: '"$INGRESS_HOSTNAME"'/g' juice-shop-chart/values.yaml
  p "sed -i '' -E 's/- host: .*/- host: '\"$INGRESS_HOSTNAME\"'/g' juice-shop-chart/values.yaml"  
  grep "\- host:" juice-shop-chart/values.yaml
  pe "helm upgrade -i juice-shop juice-shop-chart --set ingress.app_protect.enabled=false"
}

Deploy_Juice-Shop_With_App_Protect () {
  pe "cd $DEMO_SHELL_BASE_DIR"
  SYSLOG_SERVER=$(kubectl get svc syslog-svc -o jsonpath='{.spec.clusterIP}')
  #INGRESS_HOSTNAME=$(kubectl get ingress -o jsonpath='{.items[].status.loadBalancer.ingress[].hostname}')
  INGRESS_HOSTNAME=$(kubectl  get svc nginx-controller-nap-nginx-ingress -o jsonpath='{.status.loadBalancer.ingress[].hostname}')
  p "Ingress hostname is $INGRESS_HOSTNAME, update .Values.ingress.hosts.host in the values.yaml to match this hostname"
  grep "\- host:" juice-shop-chart/values.yaml
  sed -i '' -E 's/- host: .*/- host: '"$INGRESS_HOSTNAME"'/g' juice-shop-chart/values.yaml
  p "sed -i '' -E 's/- host: .*/- host: '\"$INGRESS_HOSTNAME\"'/g' juice-shop-chart/values.yaml"  
  grep "\- host:" juice-shop-chart/values.yaml
  p "The syslog server cluster IP is $SYSLOG_SERVER, update .Values.ingress.app_protect.syslog_server in the values.ymal to use this syslog server."
  grep "syslog:server" juice-shop-chart/values.yaml
  sed -i '' -E 's/([0-9]{1,3}\.){3}[0-9]{1,3}:514/'"$SYSLOG_SERVER:514"'/g' juice-shop-chart/values.yaml
  grep "syslog:server" juice-shop-chart/values.yaml

  pe "helm upgrade -i juice-shop juice-shop-chart --set ingress.app_protect.enabled=true"

}
Create_App_Protect_Policy () {
  p "Create the App Protect policy and log configuration:"
  pe "kubectl create -f $INGRESS_BASE_DIR/examples/appprotect/dataguard-alarm.yaml"
  pe "kubectl create -f $INGRESS_BASE_DIR/examples/appprotect/logconf.yaml"

}

NGINX_App_Protect_Example() {
  FQDN_NIC=$(kubectl get svc my-release-nginx-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  p "NGINX Ingress Controller IP: \"$FQDN_NIC\""
  IC_IP=$(dig +short "$FQDN_NIC")
  IC_HTTPS_PORT=443
  p "NGINX Ingress Controller IP:PORT - $IC_IP:$IC_HTTPS_PORT"
  pe "cd $INGRESS_BASE_DIR/examples/appprotect"
  pe "pwd"
  p "#Press Enter if the pwd is appprotect"
  wait
  p "Deploy the Cafe Application"
  pe "kubectl create -f cafe.yaml"

  p "Create a secret with an SSL certificate and a key:"
  pe "kubectl create -f cafe-secret.yaml"
  Deploy_Syslog_Server
  Create_App_Protect_Policy

  syslog_server=$(kubectl get svc syslog-svc -o jsonpath='{.spec.clusterIP}')
  p "Create an Ingress resource:" 

  p "Update the appprotect.f5.com/app-protect-security-log-destination annotation from cafe-ingress.yaml with the ClusterIP of the syslog service."
  Set_Syslog_Server_IP
  pe "kubectl create -f cafe-ingress.yaml"
  p "#Press, Test the Application"
  wait
  Coffee_Tea_Ingress_Test
}

Delete_Cafe_Ingress() {
  if [ -z "$1" ]
  then
    EXAMPLE_DIR="complete-example"
  else
    EXAMPLE_DIR=$1
  fi
  pe "cd $INGRESS_BASE_DIR/examples/$EXAMPLE_DIR"
  pe "pwd"
  p "#Press Enter if the pwd is $EXAMPLE_DIR"
  wait
  pe "kubectl get ingress"
  p "Delete cafe Ingress resource:"
  pe "kubectl delete -f cafe-ingress.yaml"
  pe "kubectl get ingress"
}

Add_Cafe_Ingress() {
  if [ -z "$1" ]
  then
    EXAMPLE_DIR="complete-example"
  else
    EXAMPLE_DIR=$1
  fi
  pe "cd $INGRESS_BASE_DIR/examples/$EXAMPLE_DIR"
  pe "pwd"
  p "#Press Enter if the pwd is $EXAMPLE_DIR"
  wait
  pe "kubectl get ingress"
  p "Create cafe Ingress resource:"
  pe "kubectl create -f cafe-ingress.yaml"
  pe "kubectl get ingress"
}

Coffee_Tea_Ingress_Test() {
  if [ -z "$1" ]
  then
    FQDN_NIC=$(kubectl get svc my-release-nginx-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    p "NGINX Ingress Controller IP: ""$FQDN_NIC"
    IC_IP=$(dig +short "$FQDN_NIC")
  else
    IC_IP=$1
  fi
  if [ -z "$2" ]
  then
    IC_HTTPS_PORT=443
  else 
    IC_HTTPS_PORT=$2
  fi
  p "NGINX Ingress Controller IP:PORT: $IC_IP:$IC_HTTPS_PORT"
  pe "curl --resolve cafe.example.com:$IC_HTTPS_PORT:$IC_IP https://cafe.example.com:$IC_HTTPS_PORT/coffee --insecure"
  pe "curl --resolve cafe.example.com:$IC_HTTPS_PORT:$IC_IP https://cafe.example.com:$IC_HTTPS_PORT/tea --insecure"
  pe "curl --resolve cafe.example.com:$IC_HTTPS_PORT:$IC_IP \"https://cafe.example.com:$IC_HTTPS_PORT/tea/<script>\" --insecure"

}

Check_devsecops_User () {
    p "Check if the devsecops user has been created on AWS"
    pe "aws iam list-users --query \"Users[?UserName == 'devsecops']\""
}


Delete_EKS_Cluster() {
  EKS_CLUSTER_NAME=$(eksctl get cluster -o json |jq -r ".[].name")
  p "Press enter if you want to delete EKS cluser $EKS_CLUSTER_NAME"
  wait
  pe "eksctl delete cluster --name $EKS_CLUSTER_NAME"
}

Clean_Up () {
  pe "helm uninstall juice-shop"
  pe "helm uninstall nginx-controller-nap"
  p "Revert the juice-shop-chart/values.yaml to the default setting"
  pe "cd $DEMO_SHELL_BASE_DIR"
  grep "\- host:" juice-shop-chart/values.yaml
  sed -i '' -E 's/- host: .*/- host: chart-example.local/g' juice-shop-chart/values.yaml
  p "sed -i '' -E 's/- host: .*/- host: chart-example.local/g' juice-shop-chart/values.yaml"  
  grep "\- host:" juice-shop-chart/values.yaml
  grep "syslog:server" juice-shop-chart/values.yaml
  sed -i '' -E 's/([0-9]{1,3}\.){3}[0-9]{1,3}:514/127.0.0.1:514/g' juice-shop-chart/values.yaml
  grep "syslog:server" juice-shop-chart/values.yaml
  Delete_EKS_Cluster
  p "Remeber delete the AWS ECR repositories"
}
Update_Kubeconfig() {
  p "update ~/.kube/config"
  EKS_CLUSTER_NAME=$(eksctl get cluster -o json |jq -r ".[].name")
  pe "eksctl utils write-kubeconfig --cluster=$EKS_CLUSTER_NAME"
}
test_full(){
  Create_EKS_Cluster
  Build_Push_IC_AppProtect_Image
  Onboard_NGINX_IC_App_Protect
  #Deploy_Syslog_Server
  Deploy_Juice-Shop_Without_App_Protect
  Deploy_Juice-Shop_With_App_Protect
  Check_Syslog 
  Clean_Up
}
test () {
  #Delete_Cafe_Ingress appprotect
  #Add_Cafe_Ingress
  #Onboard_NGINX_IC_App_Protect
  #Coffee_Tea_Ingress_Test
  #Coffee_Tea_Ingress_Test 34.208.92.109 443
  Create_EKS_Cluster

}
Coffee_Tea_Ingress_Example() {
  FQDN_NIC=$(kubectl get svc my-release-nginx-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  p "NGINX Ingress Controller IP: \"$FQDN_NIC\""
  IC_IP=$(dig +short "$FQDN_NIC")
  IC_HTTPS_PORT=443
  p "NGINX Ingress Controller IP:PORT: $IC_IP:$IC_HTTPS_PORT"
  pe "cd $INGRESS_BASE_DIR/examples/complete-example"
  pe "pwd"
  p "#Press Enter if the pwd is complete-example"
  wait
  p "Deploy the Cafe Application"
  pe "kubectl create -f cafe.yaml"
  p "Create a secret with an SSL certificate and a key:"
  pe "kubectl create -f cafe-secret.yaml"
  p "Create an Ingress resource:"
  pe "kubectl create -f cafe-ingress.yaml"
  p "Test the Application"
  pe "curl --resolve cafe.example.com:$IC_HTTPS_PORT:$IC_IP https://cafe.example.com:$IC_HTTPS_PORT/coffee --insecure"
  pe "curl --resolve cafe.example.com:$IC_HTTPS_PORT:$IC_IP https://cafe.example.com:$IC_HTTPS_PORT/tea --insecure"
  
}
Set_Syslog_Server_IP() {
  SYSLOG_SERVER=$(kubectl get svc syslog-svc -o jsonpath='{.spec.clusterIP}')
  p "syslog server cluster IP: $SYSLOG_SERVER"
  grep "syslog:server" $INGRESS_BASE_DIR/examples/appprotect/cafe-ingress.yaml
  sed -i '' -E 's/([0-9]{1,3}\.){3}[0-9]{1,3}:514/'"$SYSLOG_SERVER:514"'/g' $INGRESS_BASE_DIR/examples/appprotect/cafe-ingress.yaml
  grep "syslog:server" $INGRESS_BASE_DIR/examples/appprotect/cafe-ingress.yaml
}
Configure_RBAC () {
    p "Configure RBAC"
    p "Note: To perform this step you must be a cluster admin"
    p "1. Create a namespace and a service account for the Ingress controller:"
    pe "kubectl apply -f common/ns-and-sa.yaml"
    p "2. Create a cluster role and cluster role binding for the service account:"
    pe "kubectl apply -f rbac/rbac.yaml"
    p "3. (App Protect only) Create the App Protect role and role binding:"
    pe "kubectl apply -f rbac/ap-rbac.yaml"
}

Create_Common_Resources() {
    p "create resources common for most of the Ingress Controller installations:"
    p "Create a secret with a TLS certificate and a key for the default server in NGINX:"
    pe "kubectl apply -f common/default-server-secret.yaml"
    p "Note: The default server returns the Not Found page with the 404 status code for all requests for domains for which there are no Ingress rules defined. For testing purposes we include a self-signed certificate and key that we generated. However, we recommend that you use your own certificate and key."
    p "Create a config map for customizing NGINX configuration:"
    pe "kubectl apply -f common/nginx-config.yaml"
}
Create_Custom_Resources() {
    p "Create custom resource definitions for VirtualServer and VirtualServerRoute, TransportServer and Policy resources:"
    pe "kubectl apply -f common/vs-definition.yaml"
    pe "kubectl apply -f common/vsr-definition.yaml"
    pe "kubectl apply -f common/ts-definition.yaml"
    pe "kubectl apply -f common/policy-definition.yaml"
    p "create the following additional resources for the TCP and UDP load balancing features:"
    p "Create a custom resource definition for GlobalConfiguration resource:"
    pe "kubectl apply -f common/gc-definition.yaml"
    p "Create a GlobalConfiguration resource:"
    pe "kubectl apply -f common/global-configuration.yaml"
}
Create_NAP_Resources() {
    p "Create resources for NGINX App Protect"
    p "Create a custom resource definition for APPolicy and APLogConf:"
    pe "kubectl apply -f common/ap-logconf-definition.yaml"
    pe "kubectl apply -f common/ap-policy-definition.yaml"
}

Deploy_NIC_as_pod() {
    p "Deploy the Ingress Controller"
    p "create one Ingress controller pod using a deployment"
    p "#press Enter if you update the nginx-plus-ingress.yaml with the container image that you have built."
    wait
    pe "kubectl apply -f deployment/nginx-plus-ingress.yaml"
}

Deploy_NIC_as_DeamonSet() {
    p "Deploy the Ingress Controller"
    p "create one Ingress controller pod using a Deamon-Set"
    p "#press Enter if you update the nginx-plus-ingress.yaml with the container image that you have built."
    wait
    pe "kubectl apply -f daemon-set/nginx-plus-ingress.yaml"
}
azure_cd(){
cat <<EOF
  # Write your commands here
pwd
echo "$(System.DefaultWorkingDirectory)/$(Release.PrimaryArtifactSourceAlias)/drop/nginx-ingress-0.6.1.tgz"
tar xzvf $(System.DefaultWorkingDirectory)/$(Release.PrimaryArtifactSourceAlias)/drop/nginx-ingress-0.6.1.tgz
ls $(System.DefaultWorkingDirectory)
cd $(System.DefaultWorkingDirectory)/nginx-ingress
helm repo add nginx-stable https://helm.nginx.com/stable
helm repo update
kubectl create -f crds
helm upgrade -i nginx-controller-nap nginx-stable/nginx-ingress --set controller.image.repository=napmultijuiceracr.azurecr.io/nginx-plus-ingress --set controller.nginxplus=true 
helm list
EOF
}
Create_IAM_Role () {
  p "Press, Create IAM Role"

  TRUST="{ \"Version\": \"2012-10-17\", \"Statement\": [ { \"Effect\": \"Allow\", \"Principal\": { \"AWS\": \"arn:aws:iam::${AWS_ACCOUNT_ID}:root\" }, \"Action\": \"sts:AssumeRole\" } ] }"
  wait
  clear
  cat << EOF >/tmp/iam-role-policy
{"Version": "2012-10-17", "Statement": [ { "Effect": "Allow", "Action": "eks:Describe*", "Resource": "*" } ] }
EOF
  pe "cat /tmp/iam-role-policy"
  p "aws iam create-role --role-name EksWorkshopCodeBuildKubectlRole --assume-role-policy-document \"$TRUST\" --output text --query 'Role.Arn'"
  aws iam create-role --role-name EksWorkshopCodeBuildKubectlRole --assume-role-policy-document "$TRUST" --output text --query 'Role.Arn'

  p "aws iam put-role-policy --role-name EksWorkshopCodeBuildKubectlRole --policy-name eks-describe --policy-document file:///tmp/iam-role-policy"
  aws iam put-role-policy --role-name EksWorkshopCodeBuildKubectlRole --policy-name eks-describe --policy-document file:///tmp/iam-role-policy

}

Modify_AWS-Auth_ConfigMap () {
  ROLE="    - rolearn: arn:aws:iam::$AWS_ACCOUNT_ID:role/EksWorkshopCodeBuildKubectlRole\n      username: build\n      groups:\n        - system:masters"

  p "kubectl get -n kube-system configmap/aws-auth -o yaml | awk \"/mapRoles: \|/{print;print \\\"$ROLE\\\";next}1\" > /tmp/aws-auth-patch.yml"
  pe "cat /tmp/aws-auth-patch.yml"
  kubectl get -n kube-system configmap/aws-auth -o yaml | awk "/mapRoles: \|/{print;print \"$ROLE\";next}1" > /tmp/aws-auth-patch.yml

  p "kubectl patch configmap/aws-auth -n kube-system --patch \"$(cat /tmp/aws-auth-patch.yml)\""
  kubectl patch configmap/aws-auth -n kube-system --patch "$(cat /tmp/aws-auth-patch.yml)"

}
Setup_CodePipeline () {
  p "use cloud template to create a codepipeline"
  p "see https://www.eksworkshop.com/intermediate/220_codepipeline/codepipeline/"

}

Fork_GitHub_repo () {
  p "Login to GitHub and fork the sample service to your own account:"
  p "https://github.com/rnzsgh/eks-workshop-sample-api-service-go"
}
case "$DEMO" in
	Configure_RBAC)
    Configure_RBAC
    ;;
	Create_Common_Resources)
    Create_Common_Resources
    ;;
	Create_Custom_Resources)
    Create_Custom_Resources
    ;;
  Create_NAP_Resources)
    Create_NAP_Resources
    ;;
	Deploy_NIC_as_pod)
    Deploy_NIC_as_pod
    ;;
  Deploy_NIC_as_DeamonSet)
    Deploy_NIC_as_DeamonSet
    ;;
  Onboard_NGINX_IC_App_Protect)
    Onboard_NGINX_IC_App_Protect
    ;;
  Add_Cafe_Ingress)
    Add_Cafe_Ingress
    ;;
  Coffee_Tea_Ingress_Example)
    Coffee_Tea_Ingress_Example
    ;;
  Coffee_Tea_Ingress_Test)
    Coffee_Tea_Ingress_Test
    ;;
  Create_EKS_Cluster)
    Create_EKS_Cluster
    ;;
  Delete_Cafe_Ingress)
    Delete_Cafe_Ingress
    ;;
  Delete_EKS_Cluster)
    Delete_EKS_Cluster
    ;;
  Clean_Up)
    Clean_Up
    ;;
  Update_Kubeconfig)
    Update_Kubeconfig
    ;;
  Build_Push_Juice-Shop_Image)
    Build_Push_Juice-Shop_Image
    ;;
  Deploy_Juice-Shop_Without_App_Protect)
    Deploy_Juice-Shop_Without_App_Protect
    ;;
  Deploy_Juice-Shop_With_App_Protect)
    Deploy_Juice-Shop_With_App_Protect
    ;;  
  Build_Push_IC_AppProtect_Image)
    Build_Push_IC_AppProtect_Image
    ;;
  Deploy_Syslog_Server)
    Deploy_Syslog_Server
    ;;
  Set_Syslog_Server_IP)
    Set_Syslog_Server_IP
    ;;
  Clone_Kubernetes_Ingress_Repo)
    Clone_Kubernetes_Ingress_Repo
    ;;
  NGINX_App_Protect_Example)
    NGINX_App_Protect_Example
    ;;
  Create_ECR_Repo)
    p "create ECR repo $2"
    Create_ECR_Repo $2
    ;;
  Login_ECR)
    Login_ECR
    ;;
#AWS CI/CD pipeline
  Create_IAM_Role)
    Create_IAM_Role
    ;;
  Modify_AWS-Auth_ConfigMap)
    Modify_AWS-Auth_ConfigMap
    ;;
  Check_Syslog)
    Check_Syslog
    ;;
  test_sed)
    test_sed
    ;;
  test)
    test
    ;;
  test_full)
    test_full
    ;;
  *)
    p "Unknown demo: $DEMO"
    p "Usage: $0 {test|test_full}"
    p "Usage: $0 {Create_EKS_Cluster|Build_Push_IC_AppProtect_Image|Onboard_NGINX_IC_App_Protect|Deploy_Syslog_Server}"
    p "Usage: $0 {Deploy_Juice-Shop_Without_App_Protect|Deploy_Juice-Shop_With_App_Protect|Check_Syslog}"  
    p "Usage: $0 {Clean_Up|Delete_EKS_Cluster}"  
    p "Usage: $0 {Configure_RBAC|Create_Common_Resources|Create_Custom_Resources|Create_NAP_Resources}"
    p "Usage: $0 {Deploy_NIC_as_pod|Deploy_NIC_as_DeamonSet|Coffee_Tea_Ingress_Example}"

esac


