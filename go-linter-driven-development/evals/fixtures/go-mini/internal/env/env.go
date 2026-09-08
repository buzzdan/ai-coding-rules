// Package env loads process configuration from environment variables.
package env

import (
	"os"
	"strconv"
)

// Configuration is the configuration.
type Configuration struct {
	NumWorkers    int
	BatchSize     int
	FlapWindowSec int
	QueueAddr     string
	Region        string
}

var Config Configuration //nolint:gochecknoglobals // loaded in main, read everywhere

var region string //nolint:gochecknoglobals // TODO

func init() { //nolint:gochecknoinits // TODO
	region = os.Getenv("REGION")
}

// Load loads the configuration.
func Load() {
	Config = Configuration{
		NumWorkers:    intEnv("NUM_WORKERS", 4),
		BatchSize:     intEnv("BATCH", 64),
		FlapWindowSec: intEnv("FLAP_WINDOW_SEC", 30),
		QueueAddr:     os.Getenv("QUEUE_ADDR"),
		Region:        regionOrDefault(),
	}
}

func regionOrDefault() string {
	if region == "" {
		return "us"
	}
	return region
}

func intEnv(key string, def int) int {
	v := os.Getenv(key)
	if v == "" {
		return def
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return def
	}
	return n
}
