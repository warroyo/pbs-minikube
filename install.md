
#PBS install on minikube

## pre-reqs

* minikube
* helm
* uaac
* kubectl
  

## Create a cluster with minikube

we will be creating a minikube cluster, be sure that it has enough mem,cpu, disk for what you are doing.

1. create the cluster with oidc options, we will create this UAA instance later. currently a bug with helm and 1.16 k8s we need to use 1.15
```bash
minikube start --kubernetes-version="1.15.5" --memory=4096 --cpus=4 --disk-size=30GB --vm-driver=hyperkit --bootstrapper=kubeadm \
--extra-config=apiserver.authorization-mode=RBAC \
--extra-config=apiserver.oidc-ca-file=/var/lib/minikube/certs/uaa-ca.crt \
--extra-config=apiserver.oidc-issuer-url="https://uaa.minikube.local:443/oauth/token" \
--extra-config=apiserver.oidc-groups-claim="roles" \
--extra-config=apiserver.oidc-groups-prefix="oidc:" \
--extra-config=apiserver.oidc-username-claim="user_name" \
--extra-config=apiserver.oidc-username-prefix="oidc:" \
--extra-config=apiserver.oidc-client-id="pks_cluster_client"
```

2. enable ingress on minikube

```bash
minikube addons enable ingress
```


## Setup Helm

1. create a service account for toller and a role binding. then init helm.
   
```bash
kubectl create serviceaccount -n kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller
```

## Setup UAA

this may take a few minutes and retries readiness probe delay is not configurable.

1. install the helm chart. this can take a few retries and minutes to boot.

```bash
cp values.tmplate.yml values.yml
helm install eirini/uaa --namespace uaa --name uaa --values values.yml
```
2. get the minikube ip and add it to `/etc/hosts`
   
```bash
MK_IP=$(minikube ip)
echo "$MK_IP  uaa.minikube.local" >> /etc/hosts
```

3. create the pks_cluster client to mimic PKS. leave the secret empty

```bash
uaac token client get admin -s testing
uaac client add pks_cluster_client --scope="openid,roles" --authorized_grant_types="password,refresh_token" --authorities="uaa.resource" --access_token_validity 600 --refresh_token_validity 21600 --secret=""
```


4. we need to get the UAA ca cert to add to the ingress. you could creat your own also
   
```bash
SECRET=$(kubectl get pods --namespace uaa -o jsonpath='{.items[?(.metadata.name=="uaa-0")].spec.containers[?(.name=="uaa")].env[?(.name=="INTERNAL_CA_CERT")].valueFrom.secretKeyRef.name}')
CA_CERT="$(kubectl get secret $SECRET --namespace uaa -o jsonpath="{.data['internal-ca-cert']}" | base64 --decode -)"
```

5. put that ca cert into minikube
   
```bash
mkdir -p ~/.minikube/files/var/lib/minikube/certs/
echo $CA_CERT > ~/.minikube/files/var/lib/minikube/certs/uaa-ca.crt
```

6. get the cert and key to add to the ingress. take these values an put them into the `values.yml` file in place of `ingress.tls.crt` & `ingress.tls.key`

```bash
kubectl get secret $SECRET --namespace uaa -o jsonpath="{.data['uaa-server-cert']}" | base64 --decode -
#get server key
kubectl get secret $SECRET --namespace uaa -o jsonpath="{.data['uaa-server-cert-key']}" | base64 --decode -
```

7. once the certs are add we need to upgrade the ingress deployed by helm

```bash
helm upgrade uaa eirini/uaa --values values.yml
```

8. add the uaa hostname into minikube itself

```bash
minikube ip
minikube ssh \
"echo \"<ip-here>       uaa.minikube.local\" \
| sudo tee -a  /etc/hosts"
```

9. re run the exact same minikube start command again to reconfigrue the kube-api. I have had to run this a few times to get it to pick up the chnages. you can run `minikube logs | less` and look for erros on `oidc` when you dont see any , it worked


## install PBS

NOTE: minikube has certs in files duffle doesnt like it
run this `./translate.sh >> ~/.kube/config`

1. install PBS via docs. https://docs-pcf-staging.cfapps.io/platform/build-service/0-0-4/index.html

