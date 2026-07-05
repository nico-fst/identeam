package util

import (
	"strconv"
)

func StringToUint64(str string) (uint, error) {
	string64, err := strconv.ParseUint(str, 10, 64)
	if err != nil {
		return 0, err
	}

	return uint(string64), nil
}
