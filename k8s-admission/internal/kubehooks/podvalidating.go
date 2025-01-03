package kubehooks

import (
	"fmt"
	"os"
	"strings"
	"time"

	admissionv1 "k8s.io/api/admission/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/klog/v2"
)

var (
	allowedImages = os.Getenv("ALLOWED_IMAGES")
	// allowedImages = "ghcr.io,"
)

func AlwaysAllowDelayFiveSeconds(ar admissionv1.AdmissionReview) *admissionv1.AdmissionResponse {
	klog.V(2).Info("always-allow-with-delay sleeping for 5 seconds")
	time.Sleep(5 * time.Second)
	klog.V(2).Info("calling always-allow")
	reviewResponse := admissionv1.AdmissionResponse{}
	reviewResponse.Allowed = true
	reviewResponse.Result = &metav1.Status{Message: "this webhook allows all requests"}
	return &reviewResponse
}

// alwaysDeny all requests made to this function.
func AlwaysDeny(ar admissionv1.AdmissionReview) *admissionv1.AdmissionResponse {
	klog.V(2).Info("calling always-deny")
	reviewResponse := admissionv1.AdmissionResponse{}
	reviewResponse.Allowed = false
	reviewResponse.Result = &metav1.Status{Message: "this webhook denies all requests"}
	return &reviewResponse
}

// alwaysDeny all requests made to this function.
func AllowedImages(ar admissionv1.AdmissionReview) *admissionv1.AdmissionResponse {
	klog.V(2).Info("calling allowed-images")
	reviewResponse := admissionv1.AdmissionResponse{}
	reviewResponse.Allowed = true
	// If not set, allow all images
	if allowedImages == "" {
		return &reviewResponse
	}

	// Get the pod
	pod, err := getPod(ar)
	if err != nil {
		return toV1AdmissionResponseError(err)
	}
	// Get the images
	images := getImages(*pod)
	fmt.Println(images)

	for _, image := range images {
		// Handle docker.io case
		if !strings.Contains(image, ".") {
			image = "docker.io/library/" + image
		}
		// Extract the top-level domain and main domain
		hostParts := strings.Split(image, ".")
		if len(hostParts) > 1 {
			image = hostParts[len(hostParts)-2] + "." + hostParts[len(hostParts)-1]
		}
		// Strip path
		image := strings.Split(image, "/")[0]

		if !strings.Contains(allowedImages, image) {
			reviewResponse.Allowed = false
			reviewResponse.Result = &metav1.Status{Message: "This image is not allowed. Allowed images: " + allowedImages}
		}
	}
	return &reviewResponse
}
