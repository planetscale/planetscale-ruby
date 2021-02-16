package main

import "C"
import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"errors"
	"fmt"
	"io/ioutil"
	"os"
	"path"

	"github.com/mitchellh/go-homedir"
	"github.com/planetscale/planetscale-go/planetscale"
	"github.com/planetscale/sql-proxy/proxy"
	"go.uber.org/zap"
)

const accessTokenDir string = "~/.config/planetscale"

//export proxyfromenv
func proxyfromenv(org, database, branch *C.char) int {
	client, err := newClientFromEnv()
	if err != nil {
		return -1
	}

	logger, _ := zap.NewDevelopment()

	opts := proxy.Options{
		CertSource: newRemoteCertSource(client),
		LocalAddr:  "127.0.0.1:3307",
		RemoteAddr: "",
		Instance:   fmt.Sprintf("%s/%s/%s", C.GoString(org), C.GoString(database), C.GoString(branch)),
		Logger:     logger,
	}

	p, err := proxy.NewClient(opts)
	if err != nil {
		return -2
	}

	go p.Run(context.Background())
	return 0
}

//export passwordfromenv
func passwordfromenv(org, database, branch *C.char) *C.char {
	client, err := newClientFromEnv()
	if err != nil {
		return C.CString("")
	}

	status, _ := client.DatabaseBranches.GetStatus(context.Background(), &planetscale.GetDatabaseBranchStatusRequest{
		Organization: C.GoString(org),
		Database:     C.GoString(database),
		Branch:       C.GoString(branch),
	})

	return C.CString(status.Password)
}

//export proxyfromtoken
func proxyfromtoken(tokenName, token, org, database, branch *C.char) int {
	client, err := newClientFromServiceToken(C.GoString(tokenName), C.GoString(token))
	if err != nil {
		return -1
	}

	logger, _ := zap.NewDevelopment()

	opts := proxy.Options{
		CertSource: newRemoteCertSource(client),
		LocalAddr:  "127.0.0.1:3307",
		RemoteAddr: "",
		Instance:   fmt.Sprintf("%s/%s/%s", C.GoString(org), C.GoString(database), C.GoString(branch)),
		Logger:     logger,
	}

	p, err := proxy.NewClient(opts)
	if err != nil {
		return -2
	}

	go p.Run(context.Background())
	return 0
}

//export passwordfromtoken
func passwordfromtoken(tokenName, token, org, database, branch *C.char) *C.char {
	client, err := newClientFromServiceToken(C.GoString(tokenName), C.GoString(token))
	if err != nil {
		return C.CString("")
	}

	status, _ := client.DatabaseBranches.GetStatus(context.Background(), &planetscale.GetDatabaseBranchStatusRequest{
		Organization: C.GoString(org),
		Database:     C.GoString(database),
		Branch:       C.GoString(branch),
	})

	return C.CString(status.Password)
}

type remoteCertSource struct {
	client *planetscale.Client
}

func newRemoteCertSource(client *planetscale.Client) *remoteCertSource {
	return &remoteCertSource{
		client: client,
	}
}

func (r *remoteCertSource) Cert(ctx context.Context, org, db, branch string) (*proxy.Cert, error) {
	pkey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		return nil, fmt.Errorf("couldn't generate private key: %s", err)
	}

	cert, err := r.client.Certificates.Create(ctx, &planetscale.CreateCertificateRequest{
		Organization: org,
		DatabaseName: db,
		Branch:       branch,
		PrivateKey:   pkey,
	})
	if err != nil {
		return nil, err
	}

	return &proxy.Cert{
		ClientCert: cert.ClientCert,
		CACert:     cert.CACert,
		RemoteAddr: cert.RemoteAddr,
	}, nil
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
	panic("not implemented. this file is designed to be used as a shared library for FFI")
}
