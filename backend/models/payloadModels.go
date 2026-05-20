package models

type PresignedRequestPayload struct {
	ContentType string `json:"contentType"`
	SizeBytes   int    `json:"sizeBytes"`
}

type CommitUploadPayload struct {
	Key string `json:"key"`
}