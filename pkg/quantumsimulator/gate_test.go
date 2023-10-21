package quantumsimulator

import (
	"testing"
)

func TestNewGate(t *testing.T) {
	g := NewGate([][]complex128{
		{1, 0},
		{0, 1},
	})
	rows := len(g.Matrix)
	cols := len(g.Matrix[0])
	if rows != 2 || cols != 2 {
		t.Errorf("Expected a 2x2 matrix, but got %dx%d", rows, cols)
	}
}

func TestControlGate(t *testing.T) {
	// Define control and target qubits
	control := 0
	target := 1
	nQubits := 2

	// Creating a controlled-X gate using the Control function
	CXGate := X.Control(control, target, 2)

	// Define the expected matrix of the controlled-X gate
	expectedCX := [][]complex128{
		{1, 0, 0, 0},
		{0, 1, 0, 0},
		{0, 0, 0, 1},
		{0, 0, 1, 0},
	}

	// Check if the generated matrix matches the expected matrix
	for i := 0; i < (1 << nQubits); i++ {
		for j := 0; j < (1 << nQubits); j++ {
			if CXGate.Matrix[i][j] != expectedCX[i][j] {
				t.Errorf("Control function failed. Expected %v, but got %v at position (%d, %d)", expectedCX[i][j], CXGate.Matrix[i][j], i, j)
			}
		}
	}
}
