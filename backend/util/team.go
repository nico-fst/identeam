package util

import "strings"

func MakeValidSlug(input string) string {
	var b strings.Builder
	lastWasDash := false

	for _, r := range strings.ToLower(input) {
		switch {
		case r >= 'a' && r <= 'z':
			b.WriteRune(r)
			lastWasDash = false

		case r == ' ' || r == '\t' || r == '\n' || r == '\r' || r == '-' || r == '_' || r == '/':
			if b.Len() > 0 && !lastWasDash {
				b.WriteByte('-')
				lastWasDash = true
			}

		default:
			// remove invalid chars
		}
	}

	return strings.Trim(b.String(), "-")
}