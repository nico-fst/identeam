package models_test

import (
	"reflect"
	"testing"
	"time"

	"identeam/models"
)

func TestTeamsToResponsesSkipsNilEntries(t *testing.T) {
	teams := models.Teams{
		{Name: "Alpha", Slug: "alpha", Details: "first"},
		nil,
		{Name: "Beta", Slug: "beta", Details: "second"},
	}

	got := teams.ToResponses()
	want := []models.TeamResponse{
		{Name: "Alpha", Slug: "alpha", Details: "first"},
		{Name: "Beta", Slug: "beta", Details: "second"},
	}

	if !reflect.DeepEqual(got, want) {
		t.Fatalf("unexpected team responses: got %#v want %#v", got, want)
	}
}

func TestUsersToResponses(t *testing.T) {
	users := models.Users{
		{UserID: "1", Email: "one@example.com", FullName: "One", Username: "one"},
		{UserID: "2", Email: "two@example.com", FullName: "Two", Username: "two"},
	}

	got := users.ToResponses()
	want := []models.UserResponse{
		{UserID: "1", Email: "one@example.com", FullName: "One", Username: "one"},
		{UserID: "2", Email: "two@example.com", FullName: "Two", Username: "two"},
	}

	if !reflect.DeepEqual(got, want) {
		t.Fatalf("unexpected user responses: got %#v want %#v", got, want)
	}
}

func TestIdentsToResponses(t *testing.T) {
	now := time.Date(2026, 4, 9, 12, 0, 0, 0, time.UTC)
	idents := models.Idents{
		{Time: now, UserText: "first"},
		{Time: now.Add(time.Hour), UserText: "second"},
	}

	got := idents.ToResponses()
	want := []models.IdentResponse{
		{Time: now, UserText: "first"},
		{Time: now.Add(time.Hour), UserText: "second"},
	}

	if !reflect.DeepEqual(got, want) {
		t.Fatalf("unexpected ident responses: got %#v want %#v", got, want)
	}
}
