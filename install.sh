#currently a bug in helm 2.16 that breaks with the eirini helm chart must use 2.15 or earlier
brew unlink kubernetes-helm
brew install https://raw.githubusercontent.com/Homebrew/homebrew-core/3a2c4e22567885145bc7ae1bb03f00f8be169ea4/Formula/kubernetes-helm.rb
brew switch kubernetes-helm 2.14.3

currently a bug with helm and 1.16 k8s we need to use 1.15
minikube start --kubernetes-version="1.15.5" --memory=4096 --cpus=4 --disk-size=30GB --vm-driver=hyperkit --bootstrapper=kubeadm \
--extra-config=apiserver.authorization-mode=RBAC \
--extra-config=apiserver.oidc-ca-file=/var/lib/minikube/certs/uaa-ca.crt \
--extra-config=apiserver.oidc-issuer-url="https://uaa.minikube.local:443/oauth/token" \
--extra-config=apiserver.oidc-groups-claim="roles" \
--extra-config=apiserver.oidc-groups-prefix="oidc:" \
--extra-config=apiserver.oidc-username-claim="user_name" \
--extra-config=apiserver.oidc-username-prefix="oidc:" \
--extra-config=apiserver.oidc-client-id="pks_cluster_client"

minikube addons enable ingress

#this may take a few minutes and retries readiness probe delay is not configurable
kubectl create serviceaccount -n kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller
helm install eirini/uaa --namespace uaa --name uaa --values values.yml
add 192.168.64.3  uaa.minikube.local to /etc/hosts
uaac client add pks_cluster_client --scope="openid,roles" --authorized_grant_types="password,refresh_token" --authorities="uaa.resource" --access_token_validity 600 --refresh_token_validity 21600 

install PBS via docs. https://docs-pcf-staging.cfapps.io/platform/build-service/0-0-3/index.html

duffle relocate -f ./build-service-0.0.4.tgz -m relocated.json -p gcr.io/pa-warroyo --verbose

duffle install pbs-mk -c ./creds.yml  \
    --set domain=pbs.minikube.local \
    --set kubernetes_env=minikube \
    --set docker_registry=gcr.io \
    --set registry_username="_json_key" \
    --set registry_password="$(cat ~/.config/gcloud/gcr.json)" \
    --set uaa_url=https://uaa.minikube.local:443 \
    -f ./build-service-0.0.4.tgz \
    -m ./relocated.json

#minikube has certs in files duffle doesnt like it
./translate.sh >> ~/.kube/config

#need uaa cert
SECRET=$(kubectl get pods --namespace uaa -o jsonpath='{.items[?(.metadata.name=="uaa-0")].spec.containers[?(.name=="uaa")].env[?(.name=="INTERNAL_CA_CERT")].valueFrom.secretKeyRef.name}')
CA_CERT="$(kubectl get secret $SECRET --namespace uaa -o jsonpath="{.data['internal-ca-cert']}" | base64 --decode -)"

 mkdir -p ~/.minikube/files/var/lib/minikube/certs/
echo $CA_CERT > ~/.minikube/files/var/lib/minikube/certs/uaa-ca.crt

SERVER_CERT="$(kubectl get secret $SECRET --namespace uaa -o jsonpath="{.data['uaa-server-cert']}" | base64 --decode -)"
SERVER_KEY="$(kubectl get secret $SECRET --namespace uaa -o jsonpath="{.data['uaa-server-cert-key']}" | base64 --decode -)"


minikube ip
minikube ssh \
"echo \"192.168.64.3       uaa.minikube.local\" \
| sudo tee -a  /etc/hosts"