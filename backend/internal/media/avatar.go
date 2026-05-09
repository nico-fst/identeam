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

func ValidateAvatar(contentType string, sizeBytes int) error {
	if sizeBytes > (5 << 20) { // 5MiB
		return errors.New("avatar too large")
	}

	switch contentType {
	case "image/jpeg", "image/png", "image/webp":
		return nil
	default:
		return errors.New("unsupported avatar type")
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
		return "", errors.New("unsupported profile image type")
	}
}