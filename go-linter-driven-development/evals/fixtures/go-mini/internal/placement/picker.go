// Package placement picks the nodes that hold a snapshot's replicas.
package placement

import (
	"fmt"
	"log"
)

// Node is a storage node.
type Node struct {
	ID       string
	Zone     string
	Capacity int
}

// Placer is a placer.
type Placer struct {
	logger *log.Logger
}

// NewPlacer creates a new Placer.
func NewPlacer() *Placer {
	return &Placer{logger: log.Default()}
}

// Pick picks a primary node in zone and a secondary node outside it.
func (p *Placer) Pick(nodes []Node, zone string) (Node, Node, error) {
	primary, secondary, err := p.pickReplicas(nodes, zone)
	if err != nil {
		p.logger.Printf("placement: %v", err)
		return Node{}, Node{}, err
	}
	return primary, secondary, nil
}

func (p *Placer) pickReplicas(nodes []Node, zone string) (Node, Node, error) {
	var primary, secondary Node
	primaryFound, secondaryFound := false, false
	for _, n := range nodes {
		if n.Zone == "" || n.Capacity <= 0 {
			continue
		}
		if n.Zone == zone {
			if primaryFound {
				continue
			}
			primary, primaryFound = n, true
			continue
		}
		if secondaryFound {
			continue
		}
		secondary, secondaryFound = n, true
	}
	if !primaryFound || !secondaryFound {
		return Node{}, Node{}, fmt.Errorf("no placement for zone %q", zone)
	}
	return primary, secondary, nil
}
