# k8s-admission

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat-square)

A Helm chart for Kubernetes Admission Hooks

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| hegerdes |  | <https://henrikgerdes.me> |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Affinity for pod. |
| autoscaling.enabled | bool | `false` |  |
| autoscaling.maxReplicas | int | `100` |  |
| autoscaling.minReplicas | int | `1` |  |
| autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| certificates | object | `{"ca.crt":"","certmanager":{"enabled":true,"issuer":""},"existingSecretName":"","tls.crt":"","tls.key":""}` | A admission hooks needs https. Either provide own or use certmanager |
| certificates."ca.crt" | string | `""` | The base64 encoded server ca.crt - needed if certmanager is not enabled |
| certificates."tls.crt" | string | `""` | The base64 encoded server tls.crt - needed if certmanager is not enabled |
| certificates."tls.key" | string | `""` | The base64 encoded server tls.key - needed if certmanager is not enabled |
| certificates.certmanager.enabled | bool | `true` | Enables certmanager integration |
| certificates.certmanager.issuer | string | `""` | If not set creates own self-singed issuer |
| certificates.existingSecretName | string | `""` | Alternatively use an existing secret |
| commonLabels | object | `{}` | Labels applied to all manifests. |
| defaultEnvs | list | `[]` | List of default ENVs. No need to change |
| extraContainers | list | `[]` | Any additional containers. |
| extraDeploy | list | `[]` | Extra manifests |
| fullnameOverride | string | `""` | Override full release name. |
| httpRoute | object | `{"annotations":{},"enabled":false,"hostnames":["example.com"],"parentRefs":[{"name":"gateway","sectionName":"http"}],"rules":[{"matches":[{"path":{"type":"PathPrefix","value":"/headers"}}]}]}` | How the service is exposed via gateway-apis HTTPRoute. |
| httpRoute.annotations | object | `{}` | HTTPRoute annotations. |
| httpRoute.enabled | bool | `false` | HTTPRoute enabled. |
| httpRoute.hostnames | list | `["example.com"]` | Hostnames matching HTTP header. |
| httpRoute.parentRefs | list | `[{"name":"gateway","sectionName":"http"}]` | Which Gateways this Route is attached to |
| httpRoute.rules | list | `[{"matches":[{"path":{"type":"PathPrefix","value":"/headers"}}]}]` | List of rules and filters applied. |
| image.pullPolicy | string | `"IfNotPresent"` | Pull policy of that image. |
| image.repository | string | `"hegerdes/k8s-admission"` | The container registry and image to use. |
| image.tag | string | `"latest"` | The image tag and/or sha. |
| imagePullSecrets | list | `[]` | Any repository secrets needed to pull the image. |
| ingress | object | `{"annotations":{},"className":"nginx","enabled":false,"hosts":[{"host":"ingress.k8s.internal","paths":[{"path":"/","pathType":"Prefix"}]}],"tls":[]}` | How the service is exposed via ingress. |
| ingress.annotations | object | `{}` | Ingress annotations. |
| ingress.className | string | `"nginx"` | Ingress class. |
| ingress.enabled | bool | `false` | Ingress enabled. |
| ingress.hosts[0] | object | `{"host":"ingress.k8s.internal","paths":[{"path":"/","pathType":"Prefix"}]}` | Hostname and path config. |
| ingress.tls | list | `[]` | TLS config. |
| initContainers | list | `[]` | Any additional init containers. |
| mutatingWebhooks.enabled | bool | `true` | Enable the mutating webhook creation |
| mutatingWebhooks.proxyEnvInject | object | `{"enabled":true,"namespaceSelector":{"matchLabels":{"kubernetes.io/admission-inject-proxy":"true"}}}` | Enable proxy env inject webhook |
| mutatingWebhooks.proxyEnvInject.namespaceSelector | object | `{"matchLabels":{"kubernetes.io/admission-inject-proxy":"true"}}` | Enable namespace selector for the proxy env inject webhook |
| nameOverride | string | `""` | Override the application name. |
| nodeSelector | object | `{}` | Node selector for pod. |
| podAnnotations | object | `{}` | Extra annotations for the pod. |
| podContainerPort | int | `8443` | App and Container note. Change also in ENVs. |
| podEnvs | list | `[{"name":"MY_ENV","value":"MY_VAL"}]` | List of ENVs to configure the app. |
| podSecurityContext | object | `{}` | PodSecurity settings that will be applied to all containers. |
| replicaCount | int | `1` |  |
| resources | object | `{}` | Resources for the container. |
| securityContext | object | `{}` | Security settings for the container. |
| service | object | `{"annotations":{},"internalTrafficPolicy":"Cluster","ipFamilyPolicy":"SingleStack","port":8443,"prometheus":{"enabled":false,"path":"/metrics","port":8443,"scheme":"https"},"type":"ClusterIP"}` | How the service is exposed. |
| service.annotations | object | `{}` | Annotations for the service |
| service.internalTrafficPolicy | string | `"Cluster"` | Service traffic policy |
| service.ipFamilyPolicy | string | `"SingleStack"` | Service IP family |
| service.port | int | `8443` | Service and container port |
| service.prometheus | object | `{"enabled":false,"path":"/metrics","port":8443,"scheme":"https"}` | Service prometheus annotation |
| service.type | string | `"ClusterIP"` | Service type |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account. |
| serviceAccount.create | bool | `true` | Specifies whether a service account should be created. |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template. |
| tolerations | list | `[]` | Tolerations for pod. |
| validatingWebhooks.allowWithDelay.enabled | bool | `true` | Enable always allow delay webhook |
| validatingWebhooks.allowWithDelay.namespaceSelector | object | `{}` | Enable namespace selector for the proxy env inject webhook |
| validatingWebhooks.allowedImages.enabled | bool | `true` | Enable image check webhook |
| validatingWebhooks.allowedImages.namespaceSelector | object | `{}` | Enable namespace selector for the proxy env inject webhook |
| validatingWebhooks.enabled | bool | `false` | Enable the validating webhook creation |
| volumeMounts | list | `[]` | Volume mount's for container. |
| volumes | list | `[]` | Volumes where data should be persisted. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
