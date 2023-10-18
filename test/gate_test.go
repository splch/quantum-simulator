package quantum_simulator

import (
	"testing"
)

func TestApplyGate(t *testing.T) {
	state := []complex128{1, 0}
	ApplyGate(state, H, 0)
	// Test condition here based on your implementation
}

func TestHGate(t *testing.T) {
	if len(H.Matrix) != 4 {
		t.Errorf("Expected 2x2 matrix for H gate")
	}
}

func TestTGate(t *testing.T) {
	if len(T.Matrix) != 4 {
		t.Errorf("Expected 2x2 matrix for T gate")
	}
}

func TestXGate(t *testing.T) {
	if len(X.Matrix) != 4 {
		t.Errorf("Expected 2x2 matrix for X gate")
	}
}
