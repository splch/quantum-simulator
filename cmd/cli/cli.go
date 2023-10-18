package main

import (
	"flag"
	"fmt"
	"strconv"
	"strings"

	"github.com/splch/quantum_simulator/pkg/quantum_simulator"
)

func main() {
	// Create a 3-qubit circuit, apply a Hadamard gate on qubit 0, a T gate on qubit 1, and run the circuit 100 times
	// ./quantum_simulator -qubits 3 -ops "H:0,T:1" -runs 100

	// Command line flags
	qubits := flag.Int("qubits", 1, "Number of qubits in the circuit")
	operations := flag.String("ops", "", "Comma-separated list of gates to apply. Format: gate:target[,control]")
	runs := flag.Int("runs", 100, "Number of times to run the circuit")
	flag.Parse()

	// Create a new quantum circuit
	circuit := quantum_simulator.NewCircuit(*qubits)

	// Apply gates
	ops := strings.Split(*operations, ",")
	for _, op := range ops {
		parts := strings.Split(op, ":")
		if len(parts) < 2 {
			fmt.Println("Invalid gate operation:", op)
			return
		}
		gate := parts[0]
		target, err := strconv.Atoi(parts[1])
		if err != nil {
			fmt.Println("Invalid target qubit:", parts[1])
			return
		}

		switch gate {
		case "H":
			circuit.H(target)
		case "T":
			circuit.T(target)
		case "CX":
			if len(parts) < 3 {
				fmt.Println("Missing control qubit for CX gate")
				return
			}
			control, err := strconv.Atoi(parts[2])
			if err != nil {
				fmt.Println("Invalid control qubit:", parts[2])
				return
			}
			circuit.CX(control, target)
		default:
			fmt.Println("Unsupported gate:", gate)
			return
		}
	}

	// Run the circuit
	results := circuit.Run(*runs)

	// Output the results
	for state, count := range results {
		fmt.Printf("%s: %d\n", state, count)
	}
}
