package main

import (
	"flag"
	"fmt"
	"strings"

	"github.com/splch/quantumsimulator/pkg/quantumsimulator"
)

func main() {
	// Parsing command line arguments
	qubits := flag.Int("qubits", 0, "Number of qubits in the circuit")
	shots := flag.Int("shots", 100, "Number of shots")
	ops := flag.String("ops", "", "Quantum gates to apply")

	flag.Parse()

	// Validating the inputs
	if *qubits <= 0 || *shots <= 0 || *ops == "" {
		fmt.Println("Invalid input. Use -h for help.")
		return
	}

	// Creating the circuit
	circuit := quantumsimulator.NewCircuit(*qubits)

	// Applying the operations
	for _, op := range strings.Split(*ops, " ") {
		switch {
		case strings.HasPrefix(op, "H["):
			var target int
			fmt.Sscanf(op, "H[%d]", &target)
			circuit.H(target)

		case strings.HasPrefix(op, "T["):
			var target int
			fmt.Sscanf(op, "T[%d]", &target)
			circuit.T(target)

		case strings.HasPrefix(op, "CX["):
			var control, target int
			fmt.Sscanf(op, "CX[%d,%d]", &control, &target)
			circuit.CX(control, target)

		case strings.HasPrefix(op, "U("):
			var target int
			var theta, phi, lambda float64
			fmt.Sscanf(op, "U(%f,%f,%f)[%d]", &theta, &phi, &lambda, &target)
			circuit.U(target, theta, phi, lambda)

		default:
			fmt.Println("Invalid operation:", op)
			return
		}
	}

	// Running the circuit and printing the results
	results := circuit.Run(*shots)

	for state, count := range results {
		fmt.Printf("%s: %d\n", state, count)
	}
}
