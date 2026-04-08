package models

func TeamToResponse(t *Team) TeamResponse {
	if t == nil {
		return TeamResponse{}
	}

	return t.ToResponse()
}

func TeamsToResponses(teams []*Team) []TeamResponse {
	res := make([]TeamResponse, 0, len(teams))

	for _, t := range teams {
		if t == nil {
			continue
		}
		res = append(res, TeamToResponse(t))
	}

	return res
}

func UsersToResponses(users []User) []UserResponse {
	res := make([]UserResponse, 0, len(users))

	for _, user := range users {
		res = append(res, user.ToResponse())
	}

	return res
}

func IdentsToResponses(idents []Ident) []IdentResponse {
	res := make([]IdentResponse, 0, len(idents))

	for _, ident := range idents {
		res = append(res, ident.ToResponse())
	}

	return res
}
