package models

func TeamToResponse(t *Team) TeamResponse {
	if t == nil {
		return TeamResponse{}
	}

	return TeamResponse{
		Name:        t.Name,
		Slug:        t.Slug,
		Details: t.Details,
	}
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
