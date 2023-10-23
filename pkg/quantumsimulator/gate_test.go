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

func TestUGate(t *testing.T) {
	g := U(0, 0.2, 3.1)

	// Define the expected matrix of the controlled-X gate
	expectedG := [][]complex128{
		{1, 0},
		{0, complex(-0.9874797699088649, -0.15774569414324865)},
	}

	// Check if the generated matrix matches the expected matrix
	for i := 0; i < len(expectedG); i++ {
		for j := 0; j < len(expectedG); j++ {
			if g.Matrix[i][j] != expectedG[i][j] {
				t.Errorf("Control function failed. Expected %v, but got %v at position (%d, %d)", expectedG[i][j], g.Matrix[i][j], i, j)
			}
		}
	}
}

func TestPredefinedGates(t *testing.T) {
	if len(H.Matrix) != 2 || len(X.Matrix) != 2 || len(T.Matrix) != 2 {
		t.Fatalf("Expected predefined gates to have size 2x2")
	}
}

func TestControlGate(t *testing.T) {
	// Define control and target qubits
	control := 0
	target := 1
	nQubits := 2

	// Creating a controlled-X gate using the Control function
	CXGate := X.Control(control, target, nQubits)

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

func TestMultiply(t *testing.T) {
	matrix := [][]complex128{{1, 0}, {0, 1}}
	vector := []complex128{1, 2}

	result := Multiply(matrix, vector)
	if len(result) != 2 {
		t.Fatalf("Expected result vector of size 2, but got size %v", len(result))
	}
}

func TestIdentityMatrix(t *testing.T) {
	identity := IdentityMatrix(3)

	for i := 0; i < 3; i++ {
		if identity[i][i] != 1 {
			t.Fatalf("Expected diagonal elements of identity matrix to be 1")
		}
	}
}

func TestKroneckerProduct(t *testing.T) {
	m1 := [][]complex128{{1, 0}, {0, 1}}
	m2 := [][]complex128{{1, 0}, {0, 1}}

	result := kronecker(m1, m2)
	if len(result) != 4 || len(result[0]) != 4 {
		t.Fatalf("Expected result matrix of size 4x4, but got size %vx%v", len(result), len(result[0]))
	}
}
