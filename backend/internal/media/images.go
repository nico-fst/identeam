package media

import (
	"errors"
	"fmt"
	"strings"
)

func AvatarKeyString(userID string, version uint, ext string) string {
	ext = strings.TrimPrefix(strings.ToLower(ext), ".")
	return fmt.Sprintf("users/%s/profile/avatar_v%d.%s", userID, version, ext)
}

func NextAvatarKey(userID string, currentKey string, contentType string) (string, error) {
	ext, err := ContentTypeToExtension(contentType)
	if err != nil {
		return "", err
	}

	if currentKey == "" {
		return fmt.Sprintf("users/%s/profile/avatar_v1.%s", userID, ext), nil
	}

	return NextKeyVersion(currentKey)
}

func IdentImageKeyString(slug string, identID string, version uint, ext string) string {
	ext = strings.TrimPrefix(strings.ToLower(ext), ".")
	return fmt.Sprintf("teams/%s/idents/%s/image_v%d.%s", slug, identID, version, ext)
}

func NextIdentImageKey(slug string, currentKey string, identID string, contentType string) (string, error) {
	ext, err := ContentTypeToExtension(contentType)
	if err != nil {
		return "", err
	}

	if currentKey == "" {
		return fmt.Sprintf("teams/%s/idents/%s/image_v1.%s", slug, identID, ext), nil
	}

	return NextKeyVersion(currentKey)
}

func ValidateImage(contentType string, sizeBytes int) error {
	if sizeBytes > (5 << 20) { // 5MiB
		return errors.New("image too large")
	}

	switch contentType {
	case "image/jpeg", "image/png", "image/webp":
		return nil
	default:
		return errors.New("unsupported image type")
	}
}

func ContentTypeToExtension(contentType string) (string, error) {
	switch contentType {
	case "image/jpeg":
		return "jpg", nil
	case "image/png":
		return "png", nil
	case "image/webp":
		return "webp", nil
	default:
		return "", errors.New("unsupported image type (jpeg, png, webp)")
	}
}
