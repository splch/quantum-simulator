package main

import (
	"flag"
	"fmt"
	"log"
	"strconv"
	"strings"

	"github.com/splch/quantumsimulator/pkg/quantumsimulator"
)

func main() {
	var qubits int
	var shots int
	var ops string

	// Parsing command-line arguments
	flag.IntVar(&qubits, "qubits", 0, "Number of qubits in the circuit")
	flag.IntVar(&shots, "shots", 100, "Number of times to run the circuit")
	flag.StringVar(&ops, "ops", "", "Operations to be applied")

	// Custom usage message
	flag.Usage = func() {
		fmt.Printf("Usage of %s:\n", flag.CommandLine.Name())
		fmt.Println("  go run main.go -qubits NUM_QUBITS -shots NUM_SHOTS -ops 'GATE[:PARAM]:QUBIT,...'")
		fmt.Printf("Options:\n")
		flag.PrintDefaults()
		fmt.Println("Example:")
		fmt.Println("  go run main.go -qubits 3 -shots 10 -ops \"H:0,CX:0:1,U:2:0.2:0.3:0.4\"")
	}
	flag.Parse()

	// Initialize a quantum circuit
	circuit, err := quantumsimulator.NewCircuit(qubits)
	if err != nil {
		log.Fatalf("Error initializing circuit: %v", err)
	}

	// Splitting operations and applying them to the circuit
	operations := strings.Split(ops, ",")
	for _, op := range operations {
		params := strings.Split(op, ":")
		switch params[0] {
		case "H":
			qubit := parseParam(params[1])
			circuit.H(qubit)
		case "T":
			qubit := parseParam(params[1])
			circuit.T(qubit)
		case "X":
			qubit := parseParam(params[1])
			circuit.X(qubit)
		case "CX":
			control := parseParam(params[1])
			target := parseParam(params[2])
			circuit.CX(control, target)
		case "U":
			qubit := parseParam(params[1])
			theta := parseFloat(params[2])
			phi := parseFloat(params[3])
			lambda := parseFloat(params[4])
			circuit.U(qubit, theta, phi, lambda)
		default:
			fmt.Printf("error: unsupported operation %s\n", params[0])
			return
		}
	}

	// Run the circuit
	results, err := circuit.Run(100)
	if err != nil {
		log.Fatalf("Error running circuit: %v", err)
	}

	// Print measurements
	for state, count := range results {
		fmt.Printf("%s: %d\n", state, count)
	}
}

func parseParam(param string) int {
	res, err := strconv.Atoi(param)
	if err != nil {
		panic(fmt.Sprintf("error: failed parsing parameter: %s\n", param))
	}
	return res
}

func parseFloat(param string) float64 {
	res, err := strconv.ParseFloat(param, 64)
	if err != nil {
		panic(fmt.Sprintf("error: failed parsing float parameter: %s\n", param))
	}
	return res
}
