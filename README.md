# Deploy NGINX Plus Ingress Controller/App Protect on the AWS demo script

F5/NGINX released the NGINX Plus Ingress Controller for Kubernetes release 1.8.0 a few months ago. Now you can embed the NGINX App Protect WAF in the Ingress Controller.
![Securing Your Apps in Kubernetes with NGINX App Protect](https://www.nginx.com/wp-content/uploads/2020/08/NGINX-App-Protect-secure-K8s-apps_topology.png)
On the NGINX Website, there is an article about how to secure applications in Kubernetes with NGINX App Protect. Here is the link of this article https://www.nginx.com/blog/securing-apps-in-kubernetes-nginx-app-protect/.

I read the article then decided to try NGINX Plus Ingress Controller with App Protect to secure a [OWASP Juice-Shop](https://github.com/bkimminich/juice-shop) application running in the AWS EKS (Elastic Kubernetes Service) cluster. However, the Kubernetes Ingress Controller is new to me. It took me a while to read [the NGINX Ingress Controller for Kubernetes document](https://docs.nginx.com/nginx-ingress-controller/overview/) and understood how to make it work.

I logged all the commands/steps that I used in my experiments to a bash script so that I can repeat the commands for a demo easily. Later I found the [demo-magic.sh](https://github.com/paxtonhare/demo-magic), a very handy shell script. It enables me to script repeatable demos in a bash environment, so I don't have to type all the commands when I demonstrate how to build, configure and run the NGINX Plus Ingress Controller with App Protect. The demo-magic.sh](https://github.com/paxtonhare/demo-magic) can show all the commands in the script and the output of those commands.

The demo.sh script in this repo uses [demo-magic.sh](https://github.com/paxtonhare/demo-magic) to demonstrate the following functions:

- Build an [NGINX Plus Ingress Controller](https://github.com/nginxinc/kubernetes-ingress) with [App Protect](https://docs.nginx.com/nginx-ingress-controller/app-protect/installation/) container image and onboard it in a Kubernetes cluster in the AWS cloud;
- Use [Helm Chart](https://helm.sh/docs/topics/charts/) to deploy an [OWASP Juice-Shop](https://github.com/bkimminich/juice-shop) application in the Kubernetes cluster.
- The Helm Chart also deploys an NGINX Plus ingress without App Protect for the Juice-Shop app so that you can access the app from the Internet
- Enable App Protect on the NGINX Plus ingress and see it blocking the illegal request
- Check the violation event log on the Syslog server
- Modify the App Protect policy to let App Protect pass the requests that are false positive

## Prerequisite

You must install and configure the following tools before moving forward.

- Install docker, kubectl, helm, awscli, eksctl on your local machine.
- You have an AWS account and run `aws configure` command to configure it on your local machine.
- You have got an NGINX Plus/App Protect license.  
  _Note: You can send a request for NGINX Plus and NGINX App Protect trial license at https://www.nginx.com/free-trial-request/._

## Quickstart

<span style="color:red">**Note: I run and test this script in the macOS. If you run this script on a Linux machine, you may need to change sed commands in the demo.script because the sed command of the macOS is slightly different with the sed command of the Linux !!!**</span>

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
  - [NGINX Ingress Controller](https://github.com/nginxinc/kubernetes-ingress) is built with the Dockerfile `appprotect/DockerfileWithAppProtectForPlus` using the make command as follows:  
    `make DOCKERFILE=appprotect/DockerfileWithAppProtectForPlus PREFIX=xxxxxxx.dkr.ecr.us-west-2.amazonaws.com/nginx-plus-ingress-app-protect`
  - Please refer to [Building the Ingress Controller Image](https://docs.nginx.com/nginx-ingress-controller/installation/building-ingress-controller-image/) for more details.
- `./demo.sh Onboard_NGINX_IC_App_Protect`
  - Use Helm Chart to deploy NGINX Ingress Controller to the EKS cluster. The Helm Chart command as follows:
    `helm upgrade -i nginx-controller-nap nginx-stable/nginx-ingress --set controller.image.repository=xxxxxx.dkr.ecr.us-west-2.amazonaws.com/nginx-plus-ingress-app-protect --set controller.nginxplus=true --set controller.appprotect.enable=true`
- `./demo.sh Deploy_Juice-Shop_Without_App_Protect`
- `./demo.sh Deploy_Juice-Shop_With_App_Protect`
- `./demo.sh Check_Syslog`
- `./demo.sh Clean_Up`

## To-Do list

- Move App Protect annotations to the templates/ingress.yaml, make syslog_server, and App Protect policy name as variables in the values.yaml
- Add the step to modify the policy to let App Protect not block the requests that are identified as false positives.
- Change the Syslog server to the Elastic Search
- Add TLS configuration to the ingress.
