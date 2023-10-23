package main

import (
	"fmt"
	"log"

	"github.com/splch/quantumsimulator/pkg/quantumsimulator"
)

func main() {
	// Initialize a quantum circuit
	circuit, err := quantumsimulator.NewCircuit(3)
	if err != nil {
		log.Fatalf("Error initializing circuit: %v", err)
	}

	// Apply a Hadamard gate
	circuit.H(2)

	// Apply a T gate
	circuit.T(1)

	// Apply a Controlled-Not gate
	circuit.CX(2, 0)

	// Apply a Generic gate
	circuit.U(0, 0.3, 0.4, 0.5)

	// Run the circuit
	results, err := circuit.Run(100)
	if err != nil {
		log.Fatalf("Error running circuit: %v", err)
	}

	// Print measurements
	for state, count := range results {
		// Expected result:
		// 000: 46
		// 001: 4
		// 100: 4
		// 101: 46
		fmt.Printf("%s: %d\n", state, count)
	}
}
