package models_test

import (
	"reflect"
	"testing"
	"time"

	"identeam/models"
)

func TestTeamsToDTOsSkipsNilEntries(t *testing.T) {
	teams := models.Teams{
		{Name: "Alpha", Slug: "alpha", Details: "first"},
		nil,
		{Name: "Beta", Slug: "beta", Details: "second"},
	}

	got := teams.ToDTOs()
	want := []models.TeamResponse{
		{Name: "Alpha", Slug: "alpha", Details: "first"},
		{Name: "Beta", Slug: "beta", Details: "second"},
	}

	if !reflect.DeepEqual(got, want) {
		t.Fatalf("unexpected team responses: got %#v want %#v", got, want)
	}
}

func TestUsersToDTOs(t *testing.T) {
	users := models.Users{
		{UserID: "1", Email: "one@example.com", FullName: "One", Username: "one"},
		{UserID: "2", Email: "two@example.com", FullName: "Two", Username: "two"},
	}

	got := users.ToDTOs()
	want := []models.UserResponse{
		{UserID: "1", Email: "one@example.com", FullName: "One", Username: "one"},
		{UserID: "2", Email: "two@example.com", FullName: "Two", Username: "two"},
	}

	if !reflect.DeepEqual(got, want) {
		t.Fatalf("unexpected user responses: got %#v want %#v", got, want)
	}
}

func TestIdentsToDTOs(t *testing.T) {
	now := time.Date(2026, 4, 9, 12, 0, 0, 0, time.UTC)
	idents := models.Idents{
		{Time: now, UserText: "first"},
		{Time: now.Add(time.Hour), UserText: "second"},
	}

	got := idents.ToDTOs()
	want := []models.IdentResponse{
		{Time: now, UserText: "first"},
		{Time: now.Add(time.Hour), UserText: "second"},
	}

	if !reflect.DeepEqual(got, want) {
		t.Fatalf("unexpected ident responses: got %#v want %#v", got, want)
	}
}

func TestNewTeamWeekResponseAggregatesTargetsAndIdents(t *testing.T) {
	weekStart := time.Date(2026, 4, 7, 0, 0, 0, 0, time.UTC)
	targets := []models.UserWeeklyTarget{
		{
			TimeStart:   weekStart,
			TargetCount: 3,
			User: models.User{
				UserID:   "user-1",
				Email:    "one@example.com",
				FullName: "One",
				Username: "one",
			},
			Team: models.Team{
				Slug: "alpha",
			},
			Idents: []models.Ident{
				{Time: weekStart.Add(2 * time.Hour), UserText: "first"},
				{Time: weekStart.Add(3 * time.Hour), UserText: "second"},
			},
		},
		{
			TimeStart:   weekStart,
			TargetCount: 2,
			User: models.User{
				UserID:   "user-2",
				Email:    "two@example.com",
				FullName: "Two",
				Username: "two",
			},
			Team: models.Team{
				Slug: "alpha",
			},
			Idents: []models.Ident{
				{Time: weekStart.Add(4 * time.Hour), UserText: "third"},
			},
		},
	}

	got := models.NewTeamWeekResponse("fallback-slug", targets)

	if got.Slug != "alpha" {
		t.Fatalf("expected slug %q, got %q", "alpha", got.Slug)
	}
	if got.TargetSum != 5 {
		t.Fatalf("expected target sum 5, got %d", got.TargetSum)
	}
	if got.IdentSum != 3 {
		t.Fatalf("expected ident sum 3, got %d", got.IdentSum)
	}
	if len(got.Members) != 2 {
		t.Fatalf("expected 2 members, got %d", len(got.Members))
	}
	if got.Members[0].User.UserID != "user-1" {
		t.Fatalf("expected first member user %q, got %q", "user-1", got.Members[0].User.UserID)
	}
	if len(got.Members[0].Idents) != 2 {
		t.Fatalf("expected first member to have 2 idents, got %d", len(got.Members[0].Idents))
	}
}
