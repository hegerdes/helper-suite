package kubehooks

import (
	admissionv1 "k8s.io/api/admission/v1"
	admissionregistrationv1 "k8s.io/api/admissionregistration/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	pkgruntime "k8s.io/apimachinery/pkg/runtime"
	pkgserializer "k8s.io/apimachinery/pkg/runtime/serializer"
	utilruntime "k8s.io/apimachinery/pkg/util/runtime"
)

type JSONPatch struct {
	Op    string         `json:"op"`
	Path  string         `json:"path"`
	Value JSONPatchValue `json:"value"`
}

type JSONPatchValue struct {
	Name  string `json:"name"`
	Value string `json:"value"`
}

var scheme = pkgruntime.NewScheme()
var Codecs = pkgserializer.NewCodecFactory(scheme)

func addToScheme(scheme *pkgruntime.Scheme) {
	utilruntime.Must(corev1.AddToScheme(scheme))
	utilruntime.Must(admissionv1.AddToScheme(scheme))
	utilruntime.Must(admissionregistrationv1.AddToScheme(scheme))
}

func Init() {
	addToScheme(scheme)
}

func getImages(pod corev1.Pod) []string {
	var images = []string{}
	for _, container := range pod.Spec.Containers {
		images = append(images, container.Image)
	}
	for _, container := range pod.Spec.InitContainers {
		images = append(images, container.Image)
	}
	return images
}

func hasContainer(containers []corev1.Container, containerName string) bool {
	for _, container := range containers {
		if container.Name == containerName {
			return true
		}
	}
	return false
}

func toV1AdmissionResponse(err error) *admissionv1.AdmissionResponse {
	return &admissionv1.AdmissionResponse{
		Result: &metav1.Status{
			Message: err.Error(),
		},
	}
}
