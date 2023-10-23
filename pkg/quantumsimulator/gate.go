// Package quantumsimulator provides structures and functions
// for simulating quantum gates and circuits.
package quantumsimulator

import (
	"math"
	"math/cmplx"
)

// Gate struct represents a quantum gate with its matrix representation.
type Gate struct {
	Matrix [][]complex128 // Matrix representation of the quantum gate.
}

// NewGate creates and returns a Gate instance with the provided matrix.
func NewGate(matrix [][]complex128) Gate {
	return Gate{Matrix: matrix}
}

// NewUGate creates and returns a UGate instance defined by the parameters theta, phi, and lambda.
func NewUGate(theta, phi, lambda float64) Gate {
	return NewGate([][]complex128{
		{
			complex(math.Cos(theta/2), 0),
			complex(-math.Sin(theta/2), 0) * cmplx.Exp(complex(0, lambda)),
		},
		{
			cmplx.Exp(complex(0, phi)) * complex(math.Sin(theta/2), 0),
			cmplx.Exp(complex(0, phi+lambda)) * complex(math.Cos(theta/2), 0),
		},
	})
}

// Predefined quantum gates.
var (
	H = NewGate([][]complex128{ // Hadamard gate.
		{complex(1/math.Sqrt(2), 0), complex(1/math.Sqrt(2), 0)},
		{complex(1/math.Sqrt(2), 0), complex(-1/math.Sqrt(2), 0)},
	})

	X = NewGate([][]complex128{ // Pauli-X gate.
		{complex(0, 0), complex(1, 0)},
		{complex(1, 0), complex(0, 0)},
	})

	T = NewGate([][]complex128{ // T gate (π/8 gate).
		{complex(1, 0), complex(0, 0)},
		{complex(0, 0), cmplx.Exp(complex(0, math.Pi/4))},
	})
)

// Control transforms the gate into its controlled version.
// The method takes the indices of the control and target qubits,
// and the total number of qubits in the circuit.
func (gate *Gate) Control(control, target, nQubits int) Gate {
	size := 1 << nQubits
	newGate := IdentityMatrix(size)

	controlBit := 1 << (nQubits - 1 - control)
	targetBit := 1 << (nQubits - 1 - target)

	for basis := 0; basis < size; basis++ {
		if basis&controlBit == controlBit && basis&targetBit == 0 {
			targetState := basis ^ targetBit

			newGate[basis][basis] = 0
			newGate[basis][targetState] = 1
			newGate[targetState][basis] = 1
			newGate[targetState][targetState] = 0
		}
	}

	return NewGate(newGate)
}

// Multiply multiplies a given matrix with a vector and returns the resulting vector.
func Multiply(matrix [][]complex128, vector []complex128) []complex128 {
	result := make([]complex128, len(matrix))
	for i := 0; i < len(matrix); i++ {
		row := matrix[i][:len(matrix[i]):len(matrix[i])]
		for j := 0; j < len(row); j++ {
			result[i] += row[j] * vector[j]
		}
	}

	return result
}

// IdentityMatrix returns an identity matrix of size n x n.
func IdentityMatrix(n int) [][]complex128 {
	identity := make([][]complex128, n)

	for i := range identity {
		identity[i] = make([]complex128, n)
		for j := range identity[i] {
			if i == j {
				identity[i][j] = 1
			} else {
				identity[i][j] = 0
			}
		}
	}

	return identity
}

// KroneckerProduct calculates the Kronecker product of the gate with the identity matrix,
// placing the gate at the position defined by the target qubit.
func kronecker(m1, m2 [][]complex128) [][]complex128 {
	rowsM1, colsM1 := len(m1), len(m1[0])
	rowsM2, colsM2 := len(m2), len(m2[0])

	p := make([][]complex128, rowsM1*rowsM2)
	for i := range p {
		p[i] = make([]complex128, colsM1*colsM2)
	}

	for i := 0; i < rowsM1; i++ {
		for j := 0; j < colsM1; j++ {
			for k := 0; k < rowsM2; k++ {
				for l := 0; l < colsM2; l++ {
					p[i*rowsM2+k][j*colsM2+l] = m1[i][j] * m2[k][l]
				}
			}
		}
	}

	return p
}
