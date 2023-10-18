# Introduction to Quantum Simulator in Go

Welcome to the Quantum Simulator written in Go. This simulator aims to provide a simple yet effective way to simulate the behavior of quantum circuits. It allows you to apply basic quantum gates like Hadamard, T, and Controlled-Not to a quantum circuit, and observe the outcomes after running the circuit multiple times.

## Features

- **Simple API**: Initialize circuits and apply gates in just a few lines of code.
- **Predefined Gates**: Comes with Hadamard, T, and X (Pauli-X) gates pre-defined.
- **Extendable**: Easy to add new gates and operations.
- **Efficient**: Written in Go for optimal performance.

## Quick Start

1. **Install the library**

   ```shell
   go get github.com/splch/quantum-simulator
   ```
   
2. **Download dependencies**

   ```shell
   go mod tidy
   ```

3. **Build the project**

   ```shell
   make build
   ```
   
4. **Run the simulator**

   ```shell
   make run
   ```
   
## Usage Example

Here is a simple usage example where a Hadamard gate is applied to the first qubit and then a T gate is applied to the second qubit.

```go
package main

import (
	"fmt"
	"github.com/splch/quantum_simulator/pkg/quantum_simulator"
)

func main() {
	circuit := quantum_simulator.NewCircuit(3)
	circuit.H(0)
	circuit.T(1)
	results := circuit.Run(100)
	
	for state, count := range results {
		fmt.Printf("%s: %d\n", state, count)
	}
}
```

Feel free to explore and contribute to this project to make it better. Thank you for using the Quantum Simulator in Go.
