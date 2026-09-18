package main

import (
	"os"
	"os/exec"
	"strings"
	"testing"
)

func TestInstallerShellSyntax(t *testing.T) {
	if out, err := exec.Command("bash", "-n", "install.sh").CombinedOutput(); err != nil {
		t.Fatalf("install.sh syntax invalid: %s", out)
	}
}

func TestForkDistribution(t *testing.T) {
	b, err := os.ReadFile("install.sh")
	if err != nil { t.Fatal(err) }
	s := string(b)
	if !strings.Contains(s, `REPO_OWNER="GamerKhaan"`) {
		t.Fatal("installer does not fetch node-serviced releases from owned fork")
	}
	if strings.Contains(s, `REPO_OWNER="PasarGuard"`) {
		t.Fatal("installer still references upstream release owner")
	}
}
