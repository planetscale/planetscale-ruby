package main

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/tls"
	"crypto/x509"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"

	_ "net/http/pprof"

	"github.com/armon/circbuf"
	"github.com/gorilla/mux"
	"github.com/planetscale/planetscale-go/planetscale"
	"github.com/planetscale/sql-proxy/proxy"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

type controller struct {
	listenAddr string

	org, db, branch string

	logger *zap.Logger
	logBuf *circbuf.Buffer

	r *mux.Router

	client *planetscale.Client

	certSrc *localCertSource
}

func newController(org, database, branch string, opts ...controllerOpt) (*controller, error) {
	// the only way this is an error is if the bufsize is less than 0
	buf, _ := circbuf.NewBuffer(16384)

	c := &controller{
		listenAddr: "127.0.0.1:6060", // default
		org:        org,
		db:         database,
		branch:     branch,
		logBuf:     buf,
		logger:     createLogger(buf),
		r:          mux.NewRouter(),
	}

	c.r.PathPrefix("/debug/pprof/").Handler(http.DefaultServeMux)
	c.r.HandleFunc("/logs", c.logDump)
	c.r.HandleFunc("/password", c.dbPass)

	for _, v := range opts {
		if err := v(c); err != nil {
			return nil, err
		}
	}

	return c, nil
}

func (c *controller) start() error {
	opts := proxy.Options{
		CertSource: c.certSrc,
		LocalAddr:  "127.0.0.1:3307",
		Instance:   fmt.Sprintf("%s/%s/%s", c.org, c.db, c.branch),
		Logger:     c.logger,
	}

	if opts.CertSource == nil {
		opts.CertSource = newRemoteCertSource(c.client)
	}

	p, err := proxy.NewClient(opts)
	if err != nil {
		return nil
	}

	go p.Run(context.Background())
	go http.ListenAndServe(c.listenAddr, logHandler(c.logger)(c.r))
	return nil
}

func (c *controller) logDump(w http.ResponseWriter, r *http.Request) {
	w.Write(c.logBuf.Bytes())
}

func (c *controller) dbPass(w http.ResponseWriter, r *http.Request) {
	// If we've configured this with no client, we can't fetch the password
	if c.client == nil {
		w.WriteHeader(405)
		return
	}

	status, err := c.client.DatabaseBranches.GetStatus(context.Background(), &planetscale.GetDatabaseBranchStatusRequest{
		Organization: c.org,
		Database:     c.db,
		Branch:       c.branch,
	})

	if err != nil {
		w.WriteHeader(500)
		return
	}

	w.Write([]byte(status.Password))
}

func withClient(ps *planetscale.Client) controllerOpt {
	return func(c *controller) error {
		c.client = ps
		return nil
	}
}

func withListen(addr string) controllerOpt {
	return func(c *controller) error {
		c.listenAddr = addr
		return nil
	}
}

func withLocalCertSource(src *localCertSource) controllerOpt {
	return func(c *controller) error {
		c.certSrc = src
		return nil
	}
}

type controllerOpt func(c *controller) error

func createLogger(buf io.Writer) *zap.Logger {
	alwaysLog := zap.LevelEnablerFunc(func(lvl zapcore.Level) bool {
		return true
	})

	out := zapcore.Lock(zapcore.AddSync(buf))
	enc := zapcore.NewJSONEncoder(zap.NewDevelopmentEncoderConfig())
	cLog := zapcore.Lock(os.Stderr)
	cEnc := zapcore.NewConsoleEncoder(zap.NewDevelopmentEncoderConfig())
	core := zapcore.NewTee(
		zapcore.NewCore(enc, out, alwaysLog),
		zapcore.NewCore(cEnc, cLog, alwaysLog),
	)
	return zap.New(core)
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

type localCertSource struct {
	privKey     string
	certificate string
	certChain   string
	remoteAddr  string
}

func (l *localCertSource) Cert(ctx context.Context, org, db, branch string) (*proxy.Cert, error) {
	clientCert, err := tls.X509KeyPair([]byte(l.certificate), []byte(l.privKey))
	if err != nil {
		return nil, err
	}

	caCert, err := parseCert(l.certChain)
	if err != nil {
		return nil, err
	}

	return &proxy.Cert{
		ClientCert: clientCert,
		CACert:     caCert,
		RemoteAddr: l.remoteAddr,
	}, nil
}

func logHandler(l *zap.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		fn := func(w http.ResponseWriter, r *http.Request) {
			l.Info("request",
				zap.String("URL", r.URL.String()),
				zap.String("method", r.Method),
			)
			next.ServeHTTP(w, r)
		}
		return http.HandlerFunc(fn)
	}
}

func parseCert(pemCert string) (*x509.Certificate, error) {
	bl, _ := pem.Decode([]byte(pemCert))
	if bl == nil {
		return nil, errors.New("invalid PEM: " + pemCert)
	}
	return x509.ParseCertificate(bl.Bytes)
}
