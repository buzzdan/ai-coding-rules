// Command svc runs the device fleet backend.
package main

import (
	"context"
	"flag"
	"log"
	"math/rand/v2"
	"net/http"
	"os"
	"time"

	"example.com/go-mini/internal/env"
	"example.com/go-mini/internal/handlers"
	"example.com/go-mini/internal/jobs"
	"example.com/go-mini/internal/repository"
	"example.com/go-mini/internal/services"
)

func main() {
	dryRun := flag.Bool("dry-run", false, "keep devices in memory instead of the JSON store")
	storePath := flag.String("store", defaultStorePath(), "path of the JSON device store (default from STORE_PATH)")
	flag.Parse()

	env.Load()

	// Instances restarted by the same deploy would otherwise all hit the
	// queue in the same instant; a little jitter spreads them out.
	time.Sleep(time.Duration(rand.IntN(20)) * time.Millisecond)

	var (
		store repository.Store
		repo  repository.DeviceRepository
	)
	if *dryRun {
		mem := repository.NewMemStore()
		store, repo = mem, mem
	} else {
		fileRepo := mustOpenFileRepo(*storePath)
		store, repo = fileRepo, fileRepo
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	if _, err := store.List(ctx); err != nil {
		log.Fatalf("store not readable: %v", err)
	}

	notifier := services.NewNotifier(os.Getenv("WEBHOOK_URL"))
	audit := services.NewAuditLog(os.Stderr)
	svc := services.NewDeviceService(repo, notifier, audit)

	scheduler := jobs.NewScheduler()
	go scheduler.Run(ctx)

	mux := http.NewServeMux()
	routes(mux, store)
	handlers.Routes(mux, store, svc)

	addr := listenAddr()
	log.Printf("svc listening on %s (region %s, %d workers)", addr, env.Config.Region, env.Config.NumWorkers)
	srv := &http.Server{
		Addr:              addr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}
	if err := srv.ListenAndServe(); err != nil {
		log.Fatal(err)
	}
}

func mustOpenFileRepo(path string) *repository.FileRepo {
	fileRepo, err := repository.NewFileRepo(path)
	if err != nil {
		log.Fatalf("open store: %v", err)
	}
	return fileRepo
}

func routes(mux *http.ServeMux, store repository.Store) {
	mux.HandleFunc("GET /healthz", healthz(store))
}

func healthz(store repository.Store) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if _, err := store.List(r.Context()); err != nil {
			http.Error(w, "store unavailable", http.StatusServiceUnavailable)
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok\n"))
	}
}

func listenAddr() string {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	return ":" + port
}

func defaultStorePath() string {
	if p := os.Getenv("STORE_PATH"); p != "" {
		return p
	}
	return "devices.json"
}
