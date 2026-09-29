package util

import (
	"encoding/json"
	"errors"
	"identeam/models"
	"io"
	"log"
	"net/http"
)

type JSONResponse struct {
	Error   bool   `json:"error"`
	Message string `json:"message"`
	Data    any    `json:"data,omitempty"`
}

func ReadJSON(w http.ResponseWriter, r *http.Request, data any) error {
	maxBytes := 1048576                                      // max. 1MB
	r.Body = http.MaxBytesReader(w, r.Body, int64(maxBytes)) // guard: limit body size

	dec := json.NewDecoder(r.Body)
	err := dec.Decode(data) // decodes body -> data
	if err != nil {
		return err
	}
	err = dec.Decode(&struct{}{})
	if err != io.EOF {
		return errors.New("body must have only one json value")
	}

	return nil
}

// WriteJSON writes a response and logs encoding or transport errors centrally.
// A failed write must not trigger a second response after headers have been sent.
func WriteJSON(w http.ResponseWriter, status int, data any, headers ...http.Header) {
	if err := writeJSON(w, status, data, headers...); err != nil {
		log.Printf("write JSON response: %v", err)
	}
}

func writeJSON(w http.ResponseWriter, status int, data any, headers ...http.Header) error {
	out, err := json.Marshal(data)
	if err != nil {
		return err
	}

	if len(headers) > 0 { // optional
		for key, value := range headers[0] {
			w.Header()[key] = value
		}
	}

	log.Printf("(%v) %v", status, data)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)

	_, err = w.Write(out)
	if err != nil {
		return err
	}

	return nil
}

func ErrorJSON(w http.ResponseWriter, err error, status ...int) {
	statusCode := http.StatusBadRequest

	if len(status) > 0 {
		statusCode = status[0]
	}

	payload := JSONResponse{
		Error:   true,
		Message: err.Error(),
		Data:    models.Empty{},
	}

	WriteJSON(w, statusCode, payload)
}
