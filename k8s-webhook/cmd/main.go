package main

import (
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"

	"github.com/spf13/cobra"

	"github.com/hegerdes/helper-suite/k8s-admission/internal/kubehooks"
	"github.com/hegerdes/helper-suite/k8s-admission/internal/util"
	admissionv1 "k8s.io/api/admission/v1"
	pkgruntime "k8s.io/apimachinery/pkg/runtime"

	"k8s.io/klog/v2"
)

type admitv1Func func(admissionv1.AdmissionReview) *admissionv1.AdmissionResponse

var (
	certFile string
	keyFile  string
	port     int
)

// CmdWebhook is used by agnhost Cobra.
var CmdWebhook = &cobra.Command{
	Use:   "webhook",
	Short: "Starts a HTTP server, useful for testing MutatingAdmissionWebhook and ValidatingAdmissionWebhook",
	Long: `Starts a HTTP server, useful for testing MutatingAdmissionWebhook and ValidatingAdmissionWebhook.
After deploying it to Kubernetes cluster, the Administrator needs to create a ValidatingWebhookConfiguration
in the Kubernetes cluster to register remote webhook admission controllers.`,
	Args: cobra.MaximumNArgs(0),
	Run:  run,
}

func init() {
	// Port setup
	defaultPort, err := strconv.Atoi(os.Getenv("PORT"))
	if err != nil {
		defaultPort = 8080
	}

	kubehooks.Init()
	CmdWebhook.Flags().StringVar(&certFile, "tls-cert-file", "",
		"File containing the default x509 Certificate for HTTPS. (CA cert, if any, concatenated after server cert).")
	CmdWebhook.Flags().StringVar(&keyFile, "tls-private-key-file", "",
		"File containing the default x509 private key matching --tls-cert-file.")
	CmdWebhook.Flags().IntVar(&port, "port", defaultPort,
		"Secure port that the webhook listens on")
}

// serve handles the http  request prior to handing to an admitfunction
func serve(w http.ResponseWriter, r *http.Request, admit admitv1Func) {
	var body []byte
	if r.Body != nil {
		if data, err := io.ReadAll(r.Body); err == nil {
			body = data
		}
	}

	// verify the content type is accurate
	contentType := r.Header.Get("Content-Type")
	if contentType != "application/json" {
		klog.Errorf("contentType=%s, expect application/json", contentType)
		return
	}

	klog.V(2).Info(fmt.Sprintf("handling request: %s", body))

	deserializer := kubehooks.Codecs.UniversalDeserializer()
	obj, gvk, err := deserializer.Decode(body, nil, nil)
	if err != nil {
		msg := fmt.Sprintf("Request could not be decoded: %v", err)
		klog.Error(msg)
		http.Error(w, msg, http.StatusBadRequest)
		return
	}

	var responseObj pkgruntime.Object
	switch *gvk {
	case admissionv1.SchemeGroupVersion.WithKind("AdmissionReview"):
		requestedAdmissionReview, ok := obj.(*admissionv1.AdmissionReview)
		if !ok {
			klog.Errorf("Expected admissionv1.AdmissionReview but got: %T", obj)
			return
		}
		responseAdmissionReview := &admissionv1.AdmissionReview{}
		responseAdmissionReview.SetGroupVersionKind(*gvk)
		responseAdmissionReview.Response = admit(*requestedAdmissionReview)
		responseAdmissionReview.Response.UID = requestedAdmissionReview.Request.UID
		responseObj = responseAdmissionReview
	default:
		msg := fmt.Sprintf("Unsupported group version kind: %v", gvk)
		klog.Error(msg)
		http.Error(w, msg, http.StatusBadRequest)
		return
	}

	klog.V(2).Info(fmt.Sprintf("sending response: %v", responseObj))
	respBytes, err := json.Marshal(responseObj)
	if err != nil {
		klog.Error(err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	if _, err := w.Write(respBytes); err != nil {
		klog.Error(err)
	}
}

func serveAlwaysAllowDelayFiveSeconds(w http.ResponseWriter, r *http.Request) {
	serve(w, r, kubehooks.AlwaysAllowDelayFiveSeconds)
}

func serveAlwaysDeny(w http.ResponseWriter, r *http.Request) {
	serve(w, r, kubehooks.AlwaysDeny)
}
func serveSetProxyEnv(w http.ResponseWriter, r *http.Request) {
	serve(w, r, kubehooks.SetProxyEnv)
}
func serveAllowedImages(w http.ResponseWriter, r *http.Request) {
	serve(w, r, kubehooks.AllowedImages)
}

func configTLS(config util.Config) *tls.Config {
	sCert, err := tls.LoadX509KeyPair(config.CertFile, config.KeyFile)
	if err != nil {
		klog.Fatal(err)
	}
	return &tls.Config{
		Certificates: []tls.Certificate{sCert},
	}
}

func run(cmd *cobra.Command, args []string) {
	config := util.Config{
		CertFile: certFile,
		KeyFile:  keyFile,
	}

	// Validating endpoints
	http.HandleFunc("/always-allow-delay-5s", serveAlwaysAllowDelayFiveSeconds)
	http.HandleFunc("/always-deny", serveAlwaysDeny)
	http.HandleFunc("/allowed-images", serveAllowedImages)
	// Mutating endpoints
	http.HandleFunc("/add-proxy-env", serveSetProxyEnv)
	// Misc endpoints
	http.HandleFunc("/healthz", func(w http.ResponseWriter, req *http.Request) { w.Write([]byte("ok")) })
	//
	server := &http.Server{
		Addr:      fmt.Sprintf(":%d", port),
		TLSConfig: configTLS(config),
	}
	klog.Infof("Listening on %d", port)
	err := server.ListenAndServeTLS("", "")
	if err != nil {
		panic(err)
	}
}

func main() {
	if err := CmdWebhook.Execute(); err != nil {
		log.Fatal(err)
		os.Exit(1)
	}
}
