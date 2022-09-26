package main

import (
	"encoding/json"
	"fmt"
	"html/template"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"path"
	"regexp"
	"strings"
)

func main() {
	releases := getAllTerraformReleases()
	populated := populateSHASums(releases)

	t, err := template.New("terraform_versions.bzl").Parse(tmpl)
	if err != nil {
		panic(err)
	}

	f, err := os.Create(path.Join(os.Getenv("BUILD_WORKSPACE_DIRECTORY"), "toolchains", "terraform", "versions.bzl"))
	if err != nil {
		panic(err)
	}
	defer f.Close()

	err = t.Execute(f, populated)
	if err != nil {
		panic(err)
	}
}

type Build struct {
	OS   string `json:"os"`
	Arch string `json:"arch"`
	URL  string `json:"url"`
	SHA  string `json:"sha"`
}

type Release struct {
	Builds     []Build `json:"builds"`
	Version    string  `json:"version"`
	Created    string  `json:"timestamp_created"`
	SHASumsURL string  `json:"url_shasums"`
}

var (
	whitespace = regexp.MustCompile(`[^\s]+`)
)

func populateSHASums(releases []Release) []Release {
	var out []Release
	for _, release := range releases {
		r := release
		r.Builds = []Build{}

		resp, err := http.Get(release.SHASumsURL)
		if err != nil {
			log.Fatalln(err)
		}

		body, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			log.Fatalln(err)
		}

		// TODO: Verify signature of SHA file

		var fileToSha = make(map[string]string)
		for _, line := range strings.Split(string(body), "\n") {
			segments := whitespace.FindAllString(line, -1)
			if len(segments) == 2 {
				fileToSha[segments[1]] = segments[0]
			}
		}
		for _, build := range release.Builds {
			b := build
			b.SHA = fileToSha[path.Base(b.URL)]
			r.Builds = append(r.Builds, b)
		}
		out = append(out, r)
	}
	return out
}

func getAllTerraformReleases() []Release {
	var (
		out   []Release
		after string
	)
	for {
		resp, err := http.Get(fmt.Sprintf("https://api.releases.hashicorp.com/v1/releases/terraform?limit=20&after=%v", after))
		if err != nil {
			log.Fatalln(err)
		}

		body, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			log.Fatalln(err)
		}

		releases := []Release{}
		err = json.Unmarshal(body, &releases)
		if err != nil {
			log.Fatalln(err)
		}
		out = append(out, releases...)

		// Less than 20 releases returned, exit
		if len(releases) < 20 {
			break
		}
		after = releases[len(releases)-1].Created
	}
	return out
}

const tmpl = `
## Generated file - do not edit
# Below is a full set of Terraform release information, including URLs and checksums.
#
# To update this file, run:
# bazel run //tools/getreleases

VERSIONS = {
{{- range . }}
  "{{.Version}}": {
    {{- range .Builds }}
    "{{.OS}}_{{.Arch}}": {
      "url": "{{.URL}}",
      "sha": "{{.SHA}}",
    },
    {{- end }}
  },
{{- end }}
}
`
