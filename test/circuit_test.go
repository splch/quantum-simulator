package quantum_simulator

import (
	"testing"
)

func TestNewCircuit(t *testing.T) {
	circuit := NewCircuit(1)
	if circuit == nil {
		t.Errorf("Expected a new Circuit, got nil")
	}
}

func TestHadamard(t *testing.T) {
	circuit := NewCircuit(1)
	circuit.H(0)
	// Test condition here based on your implementation
}

func TestTGate(t *testing.T) {
	circuit := NewCircuit(1)
	circuit.T(0)
	// Test condition here based on your implementation
}

func TestCXGate(t *testing.T) {
	circuit := NewCircuit(2)
	circuit.CX(0, 1)
	// Test condition here based on your implementation
}

func TestRun(t *testing.T) {
	circuit := NewCircuit(1)
	circuit.H(0)
	results := circuit.Run(10)
	if results == nil {
		t.Errorf("Expected results, got nil")
	}
}
