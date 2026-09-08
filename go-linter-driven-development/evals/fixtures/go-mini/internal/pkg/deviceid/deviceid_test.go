package deviceid_test

import (
	"strings"
	"testing"

	"example.com/go-mini/internal/pkg/deviceid"
)

func TestParse_Valid(t *testing.T) {
	id, err := deviceid.Parse("  dev-42 ")
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if id.String() != "dev-42" {
		t.Fatalf("String = %q, want %q", id.String(), "dev-42")
	}
}

func TestParse_Empty(t *testing.T) {
	if _, err := deviceid.Parse("   "); err == nil {
		t.Fatal("Parse(blank) = nil error, want error")
	}
}

func TestParse_TooLong(t *testing.T) {
	if _, err := deviceid.Parse(strings.Repeat("x", 65)); err == nil {
		t.Fatal("Parse(65 chars) = nil error, want error")
	}
}
