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

var (

	// httpsProxy      = os.Getenv("HTTPS_PROXY")
	// httpProxy       = os.Getenv("HTTP_PROXY")
	// noProxy         = os.Getenv("NO_PROXY")
	httpsProxy = "http://proxy.example"
	httpProxy  = "http://proxy.example"
	noProxy    = "localhost,"

	httpProxyPatch  = JSONPatch{Op: "add", Path: "/spec/containers/0/env/0", Value: JSONPatchValue{Name: "http_proxy", Value: httpProxy}}
	httpsProxyPatch = JSONPatch{Op: "add", Path: "/spec/containers/0/env/1", Value: JSONPatchValue{Name: "https_proxy", Value: httpsProxy}}
	noProxyPatch    = JSONPatch{Op: "add", Path: "/spec/containers/0/env/2", Value: JSONPatchValue{Name: "no_proxy", Value: noProxy}}
)

// alwaysDeny all requests made to this function.
func SetProxyEnv(ar admissionv1.AdmissionReview) *admissionv1.AdmissionResponse {
	klog.V(2).Info("calling proxy-env")

	pod, err := getPod(ar)
	if err != nil {
		return toV1AdmissionResponseError(err)
	}
	mainContainerPatches := generateEnvPatches(pod.Spec.Containers)
	initContainerPatches := generateEnvPatches(pod.Spec.InitContainers)
	patches := append(mainContainerPatches, initContainerPatches...)
	bytePatches, _ := json.Marshal(patches)
	fmt.Println(string(bytePatches))

	return applyPodPatch(ar, string(bytePatches))
}

// Generate patches for setting proxy environment variables
func generateEnvPatches(containers []corev1.Container) []JSONPatch {
	var patches = []JSONPatch{}
	for index, container := range containers {
		var (
			envIndex      = 0
			httpProxySet  = false
			httpsProxySet = false
			noProxySet    = false
		)
		fmt.Println(container.Env)
		for _, env := range container.Env {
			if strings.ToLower(env.Name) == "http_proxy" {
				httpProxySet = true
			}
			if strings.ToLower(env.Name) == "https_proxy" {
				httpsProxySet = true
			}
			if strings.ToLower(env.Name) == "no_proxy" {
				noProxySet = true
			}
		}
		if !httpProxySet && httpProxy != "" {
			httpProxyPatch.Path = fmt.Sprintf("/spec/containers/%d/env/%d", index, len(container.Env)+envIndex)
			patches = append(patches, httpProxyPatch)
			envIndex++
		}
		if !httpsProxySet && httpsProxy != "" {
			httpsProxyPatch.Path = fmt.Sprintf("/spec/containers/%d/env/%d", index, len(container.Env)+envIndex)
			patches = append(patches, httpsProxyPatch)
			envIndex++
		}
		if !noProxySet && noProxy != "" {
			noProxyPatch.Path = fmt.Sprintf("/spec/containers/%d/env/%d", index, len(container.Env)+envIndex)
			patches = append(patches, noProxyPatch)
			envIndex++
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
