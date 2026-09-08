// Package transport talks to sibling fleet services over HTTP.
package transport

import (
	cryptotls "crypto/tls"
	"fmt"
	"net"
	"net/http"
	"strconv"
	"time"
)

const (
	defaultPort = 8080
	dialTimeout = 3 * time.Second
	httpTimeout = 5 * time.Second
)

// Client is a client for a sibling service.
type Client struct {
	host string
	port int
	tls  bool
	http *http.Client
}

// NewClient creates a new Client. An out-of-range port falls back to the
// default service port.
func NewClient(host string, port int, tls bool) *Client {
	if port <= 0 || port > 65535 {
		port = defaultPort
	}
	return &Client{
		host: host,
		port: port,
		tls:  tls,
		http: &http.Client{Timeout: httpTimeout},
	}
}

// HealthURL returns the health check URL of the service.
func (c *Client) HealthURL() string {
	return healthURL(c.host, c.port, c.tls)
}

// Get performs a GET against path on the service.
func (c *Client) Get(path string) (*http.Response, error) {
	scheme := "http"
	if c.tls {
		scheme = "https"
	}
	url := fmt.Sprintf("%s://%s:%d%s", scheme, c.host, c.port, path)
	resp, err := c.http.Get(url)
	if err != nil {
		return nil, fmt.Errorf("transport: get %s: %w", url, err)
	}
	return resp, nil
}

// Ping opens and closes a raw connection to the service to prove it is
// reachable before any request is sent.
func (c *Client) Ping() error {
	conn, err := dial(c.host, c.port, c.tls)
	if err != nil {
		return err
	}
	if err := conn.Close(); err != nil {
		return fmt.Errorf("transport: close ping: %w", err)
	}
	return nil
}

func dial(host string, port int, tls bool) (net.Conn, error) {
	if port <= 0 || port > 65535 {
		return nil, fmt.Errorf("transport: port %d out of range 1-65535", port)
	}
	addr := net.JoinHostPort(host, strconv.Itoa(port))
	conn, err := net.DialTimeout("tcp", addr, dialTimeout)
	if err != nil {
		return nil, fmt.Errorf("transport: dial %s: %w", addr, err)
	}
	if tls {
		return cryptotls.Client(conn, &cryptotls.Config{ServerName: host, MinVersion: cryptotls.VersionTLS12}), nil
	}
	return conn, nil
}

func healthURL(host string, port int, tls bool) string {
	scheme := "http"
	if tls {
		scheme = "https"
	}
	return fmt.Sprintf("%s://%s:%d/healthz", scheme, host, port)
}
