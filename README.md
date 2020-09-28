# Deploy NGINX Plus Ingress Controller/App Protect on the AWS demo script

The [demo-magic.sh](https://github.com/paxtonhare/demo-magic) is a handy shell script that enables you to script repeatable demos in a bash environment so you don't have to type as you present. Rather than trying to type commands when presenting you simply script them and let demo-magic.sh run
them for you.

## Prerequisite

You must install and configure the following tools before moving forward

- Install docker, kubectl, helm, awscli, eksctl on your local machine.
- You have an AWS account and run `aws configure` command to configure it on your local machine.
- You have got a NGINX Plus/App Protect license.  
  _Note: You can send a request for NGINX Plus and NGINX App Protect trial license at https://www.nginx.com/free-trial-request/._

##Quick start

- Choose a base directory, for example:

```
  mkdir ~/Documents/demo_base_dir
  cd ~/Documents/demo_base_dir
  git clone https://github.com/sgdavidw/nginx_ingress_app_protect_demo.git
  cd nginx_ingress_app_protect_demo
```

- Modify the config.ini, to change the
  BASE_DIR=~/Documents/demo_base_dir

- `./demo.sh Create_EKS_Cluster`
- `./demo.sh Build_Push_IC_AppProtect_Image`
  - For NGINX Plus, make sure that the certificate (nginx-repo.crt) and the key (nginx-repo.key) of your license are located in the root of the kubernetes_ingress project.
  - <span style="color:red">**The NGINX Plus image only can be pushed into a private registry!!!**</span>
  - NGINX Ingress Controller is built with the Dockerfile `appprotect/DockerfileWithAppProtectForPlus` using the make command as follows:  
    `make DOCKERFILE=appprotect/DockerfileWithAppProtectForPlus PREFIX=xxxxxxx.dkr.ecr.us-west-2.amazonaws.com/nginx-plus-ingress-app-protect`
  - Please refer to [Building the Ingress Controller Image](https://docs.nginx.com/nginx-ingress-controller/installation/building-ingress-controller-image/) for more details.
- `./demo.sh Onboard_NGINX_IC_App_Protect`
  - Use helm chart to deploy NGINX Ingress Controller to the EKS cluster. The helm chart command as follows:
    `helm upgrade -i nginx-controller-nap nginx-stable/nginx-ingress --set controller.image.repository=xxxxxx.dkr.ecr.us-west-2.amazonaws.com/nginx-plus-ingress-app-protect --set controller.nginxplus=true --set controller.appprotect.enable=true`
- `./demo.sh Deploy_Juice-Shop_Without_App_Protect`
- `./demo.sh Deploy_Juice-Shop_With_App_Protect`
- `./demo.sh Check_Syslog`
- `./demo.sh Clean_Up`
