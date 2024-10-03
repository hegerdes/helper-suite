# Helper-Suite
Contains different assets and binaries for shared projects.

## Content
 * Reusable github workflows
 * kube-etcd - Kubernetes and etcd in one container for easy development against the k8s api
 * http-get-push - A lambda function to make http GET's to POST's
 * crun - Containerd runc alternative, compiled with WASM support
 * youki - Containerd runc alternative, compiled with WASM support

## Kube-etcd

This is service container for services that use the Kubernetes-API.

When developing against the Kubernetes-API or validating manifests/helm-charts the Kubernetes API oten gets mocked or linters are used. These often do not cover all test-cases. This is a container that just spans a minimal, real Kubernetes-API server with etcd and accepts API-Calls **with full validation**.
No need to mock, no need for a fat minikube/kind/k3s install just one container.

### Quickstart
Just run:
```bash
docker run --rm -it -p 6443:6443 hegerdes/kubernetes-etcd

# Default token - can be overwritten
export TOKEN=31ada4fd-adec-460c-809a-9e56ceb75269

# Now you can use the API with curl
curl -kH "Authorization: Bearer $TOKEN" https://localhost:6443

# Or with kubectl
kubectl --token $TOKEN --server https://localhost:6443 --insecure-skip-tls-verify=true get pods
```
**Or use it in the CI**
```yaml
# .gitlab-ci.yaml
HELM:install:test:
  image: alpine/helm
  services:
    - name: hegerdes/kubernetes-etcd
      alias: kubernetes
  script:
    - helm upgrade --install --kube-apiserver https://kubernetes:6443 --kube-token $KUBE_TOKEN --kube-insecure-skip-tls-verify my-release my-repo/my-chart
```

### Setup Kubeconfig
```bash
# Optionally set up your kubeconfig
openssl s_client -showcerts -connect localhost:6443 </dev/null | \
    sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > k8s-ca.cert
kubectl config set-credentials demo --token="${KUBE_TOKEN}"
kubectl config set-cluster dummy --server=https://localhost:6443 \
    --certificate-authority=k8s-ca.cert --embed-certs=true
kubectl config set-context dummy-cluster --cluster=dummy --user=demo
kubectl config use-context dummy-cluster
```

### Customization
By default the container generates new certificates for communication on every new start - in no custom certs are provided.
Additionally you can:
 * Provide custom Tokens via the `USER_TOKENS` env. See [here](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#static-token-file) for format
 * Create custom etcd data dir via the `ETCD_DATA` env
 * Set a custom `CERTS_DIR`

For more options see [GitHub](https://github.com/hegerdes/helper-suite/blob/main/scripts/kube-start.sh)

### About the Tags
A new version of this container image gets published every month on the first. Supported are the there latest minor kubernetes versions with the newest patch level. Container image source can be found on [GitHub](https://github.com/hegerdes/helper-suite/blob/main/scripts/Dockerfile.kube)

### Additional Information
This is a vanilla Kubernetes-API Server. While it can accept all kind of requests, including CRDs, it can **not** actually start pods. When you need this you should use [minikube](https://minikube.sigs.k8s.io/docs/start/?arch=%2Fwindows%2Fx86-64%2Fstable%2F.exe+download) or [kind](https://kind.sigs.k8s.io/).
