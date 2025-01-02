package kubehooks

import (
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	admissionv1 "k8s.io/api/admission/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/klog/v2"
)

const (
	HTTP_PROXY_ENV  = "HTTP_PROXY"
	HTTPS_PROXY_ENV = "HTTPS_PROXY"
	NO_PROXY_ENV    = "NO_PROXY"
)

var (

	// httpsProxy      = os.Getenv(HTTPS_PROXY_ENV)
	// httpProxy       = os.Getenv(HTTP_PROXY_ENV)
	// noProxy         = os.Getenv(NO_PROXY_ENV)
	httpsProxy       = "http://proxy.example"
	httpProxy        = "http://proxy.example"
	noProxy          = "localhost,"
	httpProxyKVPair  = JSONPatchKV{Name: HTTP_PROXY_ENV, Value: httpProxy}
	httpsProxyKVPair = JSONPatchKV{Name: HTTPS_PROXY_ENV, Value: httpsProxy}
	noProxyKVPair    = JSONPatchKV{Name: NO_PROXY_ENV, Value: noProxy}
	proxyKeyValuPais = []JSONPatchKV{httpProxyKVPair, httpsProxyKVPair, noProxyKVPair}
)

// alwaysDeny all requests made to this function.
func SetProxyEnv(ar admissionv1.AdmissionReview) *admissionv1.AdmissionResponse {
	klog.V(2).Info("calling proxy-env")

	pod, err := getPod(ar)
	if err != nil {
		return toV1AdmissionResponseError(err)
	}
	mainContainerPatches := generateEnvPatches(pod.Spec.Containers, "containers")
	initContainerPatches := generateEnvPatches(pod.Spec.InitContainers, "initContainers")
	patches := append(mainContainerPatches, initContainerPatches...)
	bytePatches, _ := json.Marshal(patches)
	fmt.Println(string(bytePatches))

	return applyPodPatch(ar, string(bytePatches))
}

// Generate patches for setting proxy environment variables
func generateEnvPatches(containers []corev1.Container, containerType string) []JSONPatch {
	var patches = []JSONPatch{}
	for index, container := range containers {
		envIndex := 0
		httpProxySet := false
		httpsProxySet := false
		noProxySet := false
		if len(container.Env) == 0 {
			path := fmt.Sprintf("/spec/%s/%d/env", containerType, index)
			envPatch := JSONPatch{Op: "add", Path: path, Value: proxyKeyValuPais}
			patches = append(patches, envPatch)
		} else {
			for _, env := range container.Env {
				if strings.ToUpper(env.Name) == HTTP_PROXY_ENV {
					httpProxySet = true
				}
				if strings.ToUpper(env.Name) == HTTPS_PROXY_ENV {
					httpsProxySet = true
				}
				if strings.ToUpper(env.Name) == NO_PROXY_ENV {
					noProxySet = true
				}
			}
			if !httpProxySet && httpProxy != "" {
				path := fmt.Sprintf("/spec/%s/%d/env/-", containerType, index)
				httpProxyPatch := JSONPatch{Op: "add", Path: path, Value: httpProxyKVPair}
				patches = append(patches, httpProxyPatch)
				envIndex++
			}
			if !httpsProxySet && httpsProxy != "" {
				path := fmt.Sprintf("/spec/%s/%d/env/-", containerType, index)
				httpProxyPatch := JSONPatch{Op: "add", Path: path, Value: httpsProxyKVPair}
				patches = append(patches, httpProxyPatch)
				envIndex++
			}
			if !noProxySet && noProxy != "" {
				path := fmt.Sprintf("/spec/%s/%d/env/-", containerType, index)
				httpProxyPatch := JSONPatch{Op: "add", Path: path, Value: noProxyKVPair}
				patches = append(patches, httpProxyPatch)
				envIndex++
			}
		}
	}
	return patches
}

func applyPodPatch(ar admissionv1.AdmissionReview, patch string) *admissionv1.AdmissionResponse {

	// Create a response object
	reviewResponse := admissionv1.AdmissionResponse{}
	reviewResponse.Allowed = true

	if patch != "" && patch != "[]" {
		klog.V(2).Info("mutating pods")
		reviewResponse.Patch = []byte(patch)
		pt := admissionv1.PatchTypeJSONPatch
		reviewResponse.PatchType = &pt
	}
	return &reviewResponse
}

func getPod(ar admissionv1.AdmissionReview) (*corev1.Pod, error) {
	podResource := metav1.GroupVersionResource{Group: "", Version: "v1", Resource: "pods"}
	if ar.Request.Resource != podResource {
		klog.Errorf("expect resource to be %s", podResource)
		return nil, errors.New("resource is not an pod")
	}

	raw := ar.Request.Object.Raw
	pod := corev1.Pod{}
	deserializer := Codecs.UniversalDeserializer()
	if _, _, err := deserializer.Decode(raw, nil, &pod); err != nil {
		klog.Error(err)
		return nil, err
	} else {
		return &pod, nil
	}
}

func toV1AdmissionResponseError(err error) *admissionv1.AdmissionResponse {
	return &admissionv1.AdmissionResponse{
		Result: &metav1.Status{
			Message: err.Error(),
		},
	}
}
