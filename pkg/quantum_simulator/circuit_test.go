package quantum_simulator

import (
	"testing"
)

func TestNewCircuit(t *testing.T) {
	c := NewCircuit(2)
	if len(c.State) != 4 {
		t.Errorf("Expected state length of 4, but got %v", len(c.State))
	}
	if c.State[0] != 1 {
		t.Errorf("Expected initial state of 1, but got %v", c.State[0])
	}
}

func TestApplyHGate(t *testing.T) {
	c := NewCircuit(1)
	c.H(0)
	if c.State[0] != complex(1/1.4142135623730951, 0) {
		t.Errorf("Unexpected state after applying H gate: %v", c.State)
	}
}

func TestApplyUGate(t *testing.T) {
	c := NewCircuit(1)
	c.U(0, 1.5707963267948966, 0, 0) // Applying U gate with theta = pi/2, should be similar to H gate
	if c.State[0] != complex(0.7071067811865476, 0) {
		t.Errorf("Unexpected state after applying U gate: %v", c.State)
	}
}
