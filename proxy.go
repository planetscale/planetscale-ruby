package main

import "C"
import (
	"errors"
	"io/ioutil"
	"os"
	"path"

	"github.com/mitchellh/go-homedir"
	"github.com/planetscale/planetscale-go/planetscale"
)

const accessTokenDir string = "~/.config/planetscale"

//export startfromenv
func startfromenv(org, database, branch *C.char) int {
	client, err := newClientFromEnv()
	if err != nil {
		return 1
	}

	return startproxy(client, org, database, branch)
}

//export startfromtoken
func startfromtoken(tokenName, token, org, database, branch *C.char) int {
	client, err := newClientFromServiceToken(C.GoString(tokenName), C.GoString(token))
	if err != nil {
		return 1
	}

	return startproxy(client, org, database, branch)
}

func startproxy(ps *planetscale.Client, org, database, branch *C.char) int {
	cntrlr, err := newController(C.GoString(org), C.GoString(database), C.GoString(branch), withClient(ps))
	if err != nil {
		return 2
	}

	cntrlr.start()
	return 0
}

func newClientFromEnv() (*planetscale.Client, error) {
	opts := []planetscale.ClientOption{
		planetscale.WithBaseURL(planetscale.DefaultBaseURL),
	}

	token, err := accessToken()
	if err != nil {
		return nil, err
	}

	opts = append(opts, planetscale.WithAccessToken(token))

	return planetscale.NewClient(opts...)
}

func newClientFromServiceToken(name, token string) (*planetscale.Client, error) {
	opts := []planetscale.ClientOption{
		planetscale.WithBaseURL(planetscale.DefaultBaseURL),
		planetscale.WithServiceToken(name, token),
	}

	return planetscale.NewClient(opts...)
}

func accessToken() (string, error) {
	cfgDir, err := homedir.Expand(accessTokenDir)
	if err != nil {
		return "", err
	}
	tFile := path.Join(cfgDir, "access-token")
	if _, err := os.Stat(tFile); err != nil {
		return "", errors.New("unable to find access token file")
	}

	t, err := ioutil.ReadFile(tFile)
	if err != nil {
		return "", errors.New("unable to read access token file")
	}

	return string(t), nil
}

func main() {
}
