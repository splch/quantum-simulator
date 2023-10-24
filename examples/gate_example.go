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
		log.Fatalf("error initializing circuit: %v", err)
	}

	// Apply a Hadamard gate
	circuit.H(0)

	// Apply a T gate
	circuit.T(1)

	// Apply a Controlled-Not gate
	circuit.CX(0, 2)

	// Apply a Controlled-U Inverse gate
	circuit.CU(2, 0, 0.3, 0.4, 0.5, true)

	// Run the circuit
	results, err := circuit.Run(100)
	if err != nil {
		log.Fatalf("error running circuit: %v", err)
	}

	// Print true probabilities
	circuit.PrintState()

	// Print measurements
	for state, count := range results {
		// Expected result:
		// 000: 50
		// 001: 1
		// 101: 49
		fmt.Printf("%s: %d\n", state, count)
	}
}
