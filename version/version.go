package version

import (
	"bytes"
	"fmt"
)

var (
	BuildID       string
	Change        string
	CommitMsg     string
	CurrentCommit string
	BuildTime     string
	NewBuildURL   string
	OldBuildURL   string
	Tag           string
	Version       string
)

// Info store the version info
type Info struct {
	BuildID     string
	Change      string
	CommitMsg   string
	NewBuildURL string
	BuildTime   string
	OldBuildURL string
	Revision    string
	Tag         string
	Version     string
}

// GetVersion return the Info
func GetInfo() *Info {
	return &Info{
		BuildID:     BuildID,
		Change:      Change,
		CommitMsg:   CommitMsg,
		NewBuildURL: NewBuildURL,
		Tag:         Tag,
		OldBuildURL: OldBuildURL,
		Revision:    CurrentCommit,
		Version:     Version,
	}
}

// FullVersion return a string of the version
func (c *Info) String() string {
	var versionString bytes.Buffer

	fmt.Fprintf(&versionString, "Version: %s\n", c.Version)

	if c.BuildID != "" {
		fmt.Fprintf(&versionString, "Build ID: %s\n", c.BuildID)
	}
	if c.BuildTime != "" {
		fmt.Fprintf(&versionString, "Build Time: %s\n", c.BuildTime)
	}
	if c.Change != "" {
		fmt.Fprintf(&versionString, "Change: %s\n", c.Change)
	}
	if c.CommitMsg != "" {
		fmt.Fprintf(&versionString, "Commit Message: %s\n", c.CommitMsg)
	}
	if c.NewBuildURL != "" {
		fmt.Fprintf(&versionString, "New Build URL: %s\n", c.NewBuildURL)
	}
	if c.OldBuildURL != "" {
		fmt.Fprintf(&versionString, "Old Build URL: %s\n", c.OldBuildURL)
	}
	if c.Revision != "" {
		fmt.Fprintf(&versionString, "Revision: %s\n", c.Revision)
	}
	if c.Tag != "" {
		fmt.Fprintf(&versionString, "Tag: %s", c.Tag)
	}

	return versionString.String()
}
