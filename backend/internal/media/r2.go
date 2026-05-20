package media

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"path"
	"strconv"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
)

type R2Client struct {
	Client *s3.Client
	Bucket string
}

var (
	errS3ObjectNotFound      = errors.New("s3 object not found")
	errS3ClientNotConfigured = errors.New("r2 client is not configured")
	errS3BucketNotConfigured = errors.New("r2 bucket is not configured")
	errS3KeyMissing          = errors.New("r2 object key is required")
)

type PresignObjectOperation string

const (
	PresignObjectGet    PresignObjectOperation = "GET"
	PresignObjectPut    PresignObjectOperation = "PUT"
	PresignObjectDelete PresignObjectOperation = "DELETE"
	PresignObjectHead   PresignObjectOperation = "HEAD"
)

type PresignObjectInput struct {
	Operation   PresignObjectOperation
	Key         string
	ExpiresAt   time.Time
	ContentType string
}

// Ref: https://developers.cloudflare.com/r2/examples/aws/aws-sdk-go/
func NewR2Client() *R2Client {
	accessKeyID := os.Getenv("R2_ACCESS_KEY")
	accessKeySecret := os.Getenv("R2_SECRET_KEY")
	endpoint := os.Getenv("R2_ENDPOINT")
	bucket := os.Getenv("R2_BUCKET")

	cfg, err := config.LoadDefaultConfig(context.TODO(),
		config.WithCredentialsProvider(
			credentials.NewStaticCredentialsProvider(
				accessKeyID,
				accessKeySecret,
				"",
			),
		),
		config.WithRegion("auto"), // required by SDK but not used by R2
	)
	if err != nil {
		log.Fatal(err)
	}

	client := s3.NewFromConfig(cfg, func(o *s3.Options) {
		o.BaseEndpoint = aws.String(endpoint)
	})

	return &R2Client{
		Client: client,
		Bucket: bucket,
	}
}

func (r *R2Client) CheckExistence(ctx context.Context, key string) error {
	if r == nil || r.Client == nil {
		return errS3ClientNotConfigured
	}
	if r.Bucket == "" {
		return errS3BucketNotConfigured
	}
	if key == "" {
		return errS3KeyMissing
	}

	_, err := r.Client.HeadObject(ctx, &s3.HeadObjectInput{
		Bucket: aws.String(r.Bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		var notFound *types.NotFound
		if errors.As(err, &notFound) {
			return errS3ObjectNotFound
		}

		return err
	}

	return nil
}

func (r *R2Client) PresignObject(ctx context.Context, input PresignObjectInput) (string, error) {
	if r == nil || r.Client == nil {
		return "", errS3ClientNotConfigured
	}
	if r.Bucket == "" {
		return "", errS3BucketNotConfigured
	}
	if input.Key == "" {
		return "", errS3KeyMissing
	}

	presignClient := s3.NewPresignClient(r.Client)
	presignExpires := s3.WithPresignExpires(time.Until(input.ExpiresAt))
	bucket := aws.String(r.Bucket)
	key := aws.String(input.Key)

	switch input.Operation {
	case PresignObjectGet:
		req, err := presignClient.PresignGetObject(ctx, &s3.GetObjectInput{
			Bucket: bucket,
			Key:    key,
		}, presignExpires)
		if err != nil {
			return "", err
		}

		return req.URL, nil
	case PresignObjectPut:
		putInput := &s3.PutObjectInput{
			Bucket: bucket,
			Key:    key,
		}
		if input.ContentType != "" {
			putInput.ContentType = aws.String(input.ContentType)
		}

		req, err := presignClient.PresignPutObject(ctx, putInput, presignExpires)
		if err != nil {
			return "", err
		}

		return req.URL, nil
	case PresignObjectDelete:
		req, err := presignClient.PresignDeleteObject(ctx, &s3.DeleteObjectInput{
			Bucket: bucket,
			Key:    key,
		}, presignExpires)
		if err != nil {
			return "", err
		}

		return req.URL, nil
	case PresignObjectHead:
		req, err := presignClient.PresignHeadObject(ctx, &s3.HeadObjectInput{
			Bucket: bucket,
			Key:    key,
		}, presignExpires)
		if err != nil {
			return "", err
		}

		return req.URL, nil
	default:
		return "", errors.New("unsupported r2 presign operation")
	}
}

func (r *R2Client) PresignGetObject(ctx context.Context, key string, expiresAt time.Time) (string, error) {
	return r.PresignObject(ctx, PresignObjectInput{
		Operation: PresignObjectGet,
		Key:       key,
		ExpiresAt: expiresAt,
	})
}

func (r *R2Client) PresignPutObject(ctx context.Context, key string, contentType string, expiresAt time.Time) (string, error) {
	return r.PresignObject(ctx, PresignObjectInput{
		Operation:   PresignObjectPut,
		Key:         key,
		ExpiresAt:   expiresAt,
		ContentType: contentType,
	})
}

func (r *R2Client) PresignDeleteObject(ctx context.Context, key string, expiresAt time.Time) (string, error) {
	return r.PresignObject(ctx, PresignObjectInput{
		Operation: PresignObjectDelete,
		Key:       key,
		ExpiresAt: expiresAt,
	})
}

func (r *R2Client) PresignHeadObject(ctx context.Context, key string, expiresAt time.Time) (string, error) {
	return r.PresignObject(ctx, PresignObjectInput{
		Operation: PresignObjectHead,
		Key:       key,
		ExpiresAt: expiresAt,
	})
}

func NextKeyVersion(currentKey string) (string, error) {
	ext := path.Ext(currentKey)
	if ext == "" {
		return "", errors.New("s3 key has no file extension")
	}

	keyWithoutExtension := strings.TrimSuffix(currentKey, ext)

	versionIndex := strings.LastIndex(keyWithoutExtension, "_v")
	if versionIndex == -1 {
		return fmt.Sprintf("%s_v1%s", keyWithoutExtension, ext), nil
	}

	keyWithoutVersion := keyWithoutExtension[:versionIndex]
	versionString := keyWithoutExtension[versionIndex+len("_v"):]

	version, err := strconv.Atoi(versionString)
	if err != nil {
		return "", fmt.Errorf("failed to parse s3 key version: %w", err)
	}

	return fmt.Sprintf("%s_v%d%s", keyWithoutVersion, version+1, ext), nil
}
