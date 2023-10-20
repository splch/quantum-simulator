package quantumsimulator

import (
	"testing"
)

func TestNewGate(t *testing.T) {
	g := NewGate([][]complex128{
		{1, 0},
		{0, 1},
	})
	if len(g.Matrix) != 2 || len(g.Matrix[0]) != 2 {
		t.Errorf("Expected a 2x2 matrix, but got a different size")
	}
}

func TestControlGate(t *testing.T) {
	xGate := X
	cxGate := xGate.Control()

	expectedMatrix := [][]complex128{
		{1, 0, 0, 0},
		{0, 1, 0, 0},
		{0, 0, 0, 1},
		{0, 0, 1, 0},
	}

	if len(cxGate.Matrix) != 4 || len(cxGate.Matrix[0]) != 4 {
		t.Errorf("Expected a 4x4 matrix for the controlled gate, but got a different size")
	}
	for i := range expectedMatrix {
		for j := range expectedMatrix[i] {
			if cxGate.Matrix[i][j] != expectedMatrix[i][j] {
				t.Errorf("Expected element Matrix[%d][%d] to be %v, but got %v", i, j, expectedMatrix[i][j], cxGate.Matrix[i][j])
			}
		}
	}
}
