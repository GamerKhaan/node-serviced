package main

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writeFakeNodeCLI(t *testing.T, name string) string {
	t.Helper()
	dir := t.TempDir()
	path := filepath.Join(dir, name)
	script := "#!/bin/sh\nprintf '%s\\n' \"$@\" > \"$QA_ARGS_PATH\"\n"
	if err := os.WriteFile(path, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir+":"+os.Getenv("PATH"))
	return path
}

func TestHandleUpdateRunsOwnedNodeCLIWithoutServiceRecursion(t *testing.T) {
	writeFakeNodeCLI(t, "qa-node")
	argsPath := filepath.Join(t.TempDir(), "args.txt")
	t.Setenv("QA_ARGS_PATH", argsPath)

	s := &server{cfg: config{AppName: "qa-node", APIKey: "test-key"}}
	req := httptest.NewRequest(http.MethodPost, "/node/update", nil)
	req.Header.Set("x-api-key", "test-key")
	rec := httptest.NewRecorder()

	s.handleUpdate(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
	}
	got, err := os.ReadFile(argsPath)
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != "update\n--no-update-service\n" {
		t.Fatalf("unexpected node CLI args: %q", got)
	}
	if !strings.Contains(rec.Body.String(), "node updated successfully") {
		t.Fatalf("unexpected response: %s", rec.Body.String())
	}
}

func TestHandleUpdateRejectsInvalidAPIKeyBeforeCommand(t *testing.T) {
	writeFakeNodeCLI(t, "qa-node")
	argsPath := filepath.Join(t.TempDir(), "args.txt")
	t.Setenv("QA_ARGS_PATH", argsPath)

	s := &server{cfg: config{AppName: "qa-node", APIKey: "test-key"}}
	req := httptest.NewRequest(http.MethodPost, "/node/update", nil)
	req.Header.Set("x-api-key", "wrong-key")
	rec := httptest.NewRecorder()

	s.handleUpdate(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d: %s", rec.Code, rec.Body.String())
	}
	if _, err := os.Stat(argsPath); !os.IsNotExist(err) {
		t.Fatalf("node CLI should not run for invalid API key; stat err=%v", err)
	}
}
