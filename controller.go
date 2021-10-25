package main

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"time"

	_ "net/http/pprof"

	"github.com/armon/circbuf"
	"github.com/gorilla/mux"
	"github.com/planetscale/planetscale-go/planetscale"
	"github.com/planetscale/sql-proxy/proxy"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

type controller struct {
	localAddr string

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
		org:    org,
		db:     database,
		branch: branch,
		logBuf: buf,
		logger: createLogger(buf),
		r:      mux.NewRouter(),
	}

	c.r.PathPrefix("/debug/pprof/").Handler(http.DefaultServeMux)
	c.r.HandleFunc("/logs", c.logDump)

	for _, v := range opts {
		if err := v(c); err != nil {
			return nil, err
		}
	}

	return c, nil
}

func (c *controller) start() (string, error) {
	opts := proxy.Options{
		CertSource: c.certSrc,
		LocalAddr:  "127.0.0.1:3305", // default
		Instance:   fmt.Sprintf("%s/%s/%s", c.org, c.db, c.branch),
		Logger:     c.logger,
	}

	if c.localAddr != "" {
		opts.LocalAddr = c.localAddr
	}

	if c.certSrc == nil {
		opts.CertSource = newRemoteCertSource(c.client)
	}

	p, err := proxy.NewClient(opts)
	if err != nil {
		return "", err
	}

	errs := make(chan error)
	listener := make(chan string)
	var listenAddr string

	go func(errs chan error) {
		err := p.Run(context.Background())
		if err != nil {
			c.logger.With(zap.String("error", err.Error())).Error("unable to start listener")
			errs <- err
		}
	}(errs)

	go func(errs chan error, addr chan string) {
		listenAddr, err := p.LocalAddr()
		if err != nil {
			errs <- err
			return
		}
		listener <- listenAddr.String()
	}(errs, listener)

	select {
	case err := <-errs:
		return "", err
	case <-time.After(5 * time.Second):
		return "", errors.New("timed out waiting for proxy listener")
	case listenAddr = <-listener:
	}

	c.logger.With(zap.String("addr", listenAddr)).Debug("proxy started")

	return listenAddr, nil
}

func (c *controller) logDump(w http.ResponseWriter, r *http.Request) {
	w.Write(c.logBuf.Bytes())
}

func withClient(ps *planetscale.Client) controllerOpt {
	return func(c *controller) error {
		c.client = ps
		return nil
	}
}

func withListen(addr string) controllerOpt {
	return func(c *controller) error {
		c.localAddr = addr
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
	pkey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
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
		AccessHost: cert.AccessHost,
		Ports: proxy.RemotePorts{
			Proxy: cert.Ports.Proxy,
		},
	}, nil
}

type localCertSource struct {
	privKey     string
	certificate string
	remoteAddr  string
	port        string
}

func (l *localCertSource) Cert(ctx context.Context, org, db, branch string) (*proxy.Cert, error) {
	clientCert, err := tls.X509KeyPair([]byte(l.certificate), []byte(l.privKey))
	if err != nil {
		return nil, err
	}

	port, err := strconv.Atoi(l.port)
	if err != nil {
		return nil, err
	}

	return &proxy.Cert{
		ClientCert: clientCert,
		AccessHost: l.remoteAddr,
		Ports: proxy.RemotePorts{
			Proxy: port,
		},
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
