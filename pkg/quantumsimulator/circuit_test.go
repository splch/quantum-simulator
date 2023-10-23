package quantumsimulator

import (
	"math/cmplx"
	"testing"
)

func TestNewCircuit(t *testing.T) {
	_, err := NewCircuit(3)
	if err != nil {
		t.Fatalf("Error initializing circuit: %v", err)
	}

	_, err = NewCircuit(-1)
	if err == nil {
		t.Fatalf("Expected error for non-positive qubit number, but got none")
	}
}

func TestApplyGate(t *testing.T) {
	circuit, _ := NewCircuit(2)

	err := circuit.ApplyGate(H, 1)
	if err != nil {
		t.Fatalf("Error applying gate: %v", err)
	}

	err = circuit.ApplyGate(X, 3)
	if err == nil {
		t.Fatalf("Expected error for out-of-range target qubit, but got none")
	}
}

func TestCircuitGates(t *testing.T) {
	circuit, _ := NewCircuit(1)

	circuit.H(0)
	circuit.X(0)
	circuit.T(0)
	circuit.U(0, 0.2, 0.5, 3.1)

	expectedState := []complex128{
		complex(0.7555233002473909, 0.04779796807328487),
		complex(-0.1640332519414212, -0.6324499895555995),
	}

	if len(circuit.State) != len(expectedState) {
		t.Fatalf("Expected state length %v, but got %v", len(expectedState), len(circuit.State))
	}

	const tolerance = 1e-9
	for i, val := range expectedState {
		diff := cmplx.Abs(val - circuit.State[i])
		if diff > tolerance {
			t.Fatalf("Expected state at index %v to be %v, but got %v", i, val, circuit.State[i])
		}
	}
}

func TestControlledGates(t *testing.T) {
	circuit, _ := NewCircuit(2)

	circuit.CX(0, 1)

	// Additional logic to check the state can be added based on expected outcomes.
}

func TestRun(t *testing.T) {
	circuit, _ := NewCircuit(2)
	circuit.H(0)
	circuit.H(1)

	results, err := circuit.Run(100)
	if err != nil {
		t.Fatalf("Error running circuit: %v", err)
	}

	if len(results) == 0 {
		t.Fatalf("Expected measurement results, but got none")
	}
}

func TestRunError(t *testing.T) {
	circuit, _ := NewCircuit(2)

	_, err := circuit.Run(-5)
	if err == nil {
		t.Fatalf("Expected error for non-positive shots, but got none")
	}
}
