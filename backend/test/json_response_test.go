package test

import (
	"bytes"
	"errors"
	"log"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"identeam/util"
)

type failedResponseWriter struct {
	header       http.Header
	statusWrites int
	bodyWrites   int
}

func (w *failedResponseWriter) Header() http.Header { return w.header }
func (w *failedResponseWriter) WriteHeader(int)     { w.statusWrites++ }
func (w *failedResponseWriter) Write([]byte) (int, error) {
	w.bodyWrites++
	return 0, errors.New("test connection closed")
}

func TestJSONResponsesLogWriteErrorsWithoutRetry(t *testing.T) {
	var output bytes.Buffer
	old := log.Writer()
	log.SetOutput(&output)
	t.Cleanup(func() { log.SetOutput(old) })
	for _, respond := range []func(http.ResponseWriter){
		func(w http.ResponseWriter) { util.WriteJSON(w, http.StatusOK, util.JSONResponse{Message: "ok"}) },
		func(w http.ResponseWriter) { util.ErrorJSON(w, errors.New("unauthorized"), http.StatusUnauthorized) },
	} {
		output.Reset()
		w := &failedResponseWriter{header: make(http.Header)}
		respond(w)
		if w.statusWrites != 1 || w.bodyWrites != 1 {
			t.Fatal("must not retry a failed response")
		}
		if !strings.Contains(output.String(), "write JSON response: test connection closed") {
			t.Fatal("write error was not logged")
		}
	}
}

func TestJSONResponsePreservesStatusAndBody(t *testing.T) {
	w := httptest.NewRecorder()
	util.ErrorJSON(w, errors.New("unauthorized"), http.StatusUnauthorized)
	if w.Code != http.StatusUnauthorized || w.Header().Get("Content-Type") != "application/json" || !strings.Contains(w.Body.String(), `"message":"unauthorized"`) {
		t.Fatalf("unexpected response: %d %s", w.Code, w.Body.String())
	}
}
