package media

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

func newTestR2Client() *R2Client {
	cfg := aws.Config{
		Region:      "auto",
		Credentials: credentials.NewStaticCredentialsProvider("test-access-key", "test-secret-key", ""),
	}

	client := s3.NewFromConfig(cfg, func(o *s3.Options) {
		o.BaseEndpoint = aws.String("https://example.r2.cloudflarestorage.com")
	})

	return &R2Client{
		Client: client,
		Bucket: "test-bucket",
	}
}

func TestPresignObjectSupportsObjectOperations(t *testing.T) {
	ctx := context.Background()
	client := newTestR2Client()
	expiresAt := time.Now().Add(time.Minute)

	tests := []struct {
		name  string
		input PresignObjectInput
	}{
		{
			name: "get object",
			input: PresignObjectInput{
				Operation: PresignObjectGet,
				Key:       "users/user-1/avatar.jpg",
				ExpiresAt: expiresAt,
			},
		},
		{
			name: "put object",
			input: PresignObjectInput{
				Operation:   PresignObjectPut,
				Key:         "users/user-1/avatar.jpg",
				ExpiresAt:   expiresAt,
				ContentType: "image/jpeg",
			},
		},
		{
			name: "delete object",
			input: PresignObjectInput{
				Operation: PresignObjectDelete,
				Key:       "users/user-1/avatar.jpg",
				ExpiresAt: expiresAt,
			},
		},
		{
			name: "head object",
			input: PresignObjectInput{
				Operation: PresignObjectHead,
				Key:       "users/user-1/avatar.jpg",
				ExpiresAt: expiresAt,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			url, err := client.presignObject(ctx, tt.input)
			if err != nil {
				t.Fatalf("presignObject returned error: %v", err)
			}

			if url == "" {
				t.Fatal("expected presigned URL")
			}
			if !strings.Contains(url, "users/user-1/avatar.jpg") {
				t.Fatalf("expected URL to contain object key, got %q", url)
			}
		})
	}
}

func TestPresignGetObjectUsesGenericPresignObject(t *testing.T) {
	url, err := newTestR2Client().PresignGetObject(context.Background(), "users/user-1/avatar.jpg", time.Now().Add(time.Minute))
	if err != nil {
		t.Fatalf("PresignGetObject returned error: %v", err)
	}

	if url == "" {
		t.Fatal("expected presigned URL")
	}
}

func TestPresignObjectValidatesInput(t *testing.T) {
	ctx := context.Background()
	expiresAt := time.Now().Add(time.Minute)

	tests := []struct {
		name    string
		client  *R2Client
		input   PresignObjectInput
		wantErr string
	}{
		{
			name:    "nil client",
			client:  nil,
			input:   PresignObjectInput{Operation: PresignObjectGet, Key: "key", ExpiresAt: expiresAt},
			wantErr: "r2 client is not configured",
		},
		{
			name:    "missing bucket",
			client:  &R2Client{Client: newTestR2Client().Client},
			input:   PresignObjectInput{Operation: PresignObjectGet, Key: "key", ExpiresAt: expiresAt},
			wantErr: "r2 bucket is not configured",
		},
		{
			name:    "missing key",
			client:  newTestR2Client(),
			input:   PresignObjectInput{Operation: PresignObjectGet, ExpiresAt: expiresAt},
			wantErr: "r2 object key is required",
		},
		{
			name:    "unsupported operation",
			client:  newTestR2Client(),
			input:   PresignObjectInput{Operation: "COPY", Key: "key", ExpiresAt: expiresAt},
			wantErr: "unsupported r2 presign operation",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := tt.client.presignObject(ctx, tt.input)
			if err == nil {
				t.Fatal("expected error")
			}
			if err.Error() != tt.wantErr {
				t.Fatalf("expected error %q, got %q", tt.wantErr, err.Error())
			}
		})
	}
}
