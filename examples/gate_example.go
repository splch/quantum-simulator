package main

import (
	"fmt"

	"github.com/splch/quantumsimulator/pkg/quantumsimulator"
)

func main() {
	// Initialize a quantum circuit
	circuit := quantumsimulator.NewCircuit(3)

	// Apply a Hadamard gate
	circuit.H(0)

	// Apply a T gate
	circuit.T(1)

	// Apply a Controlled-Not gate
	circuit.CX(0, 2)

	// Apply a Generic gate
	circuit.U(2, 0.3, 0.4, 0.5)

	// Run the circuit
	results := circuit.Run(100)

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
