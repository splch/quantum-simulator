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

// U creates and returns a U Gate instance defined by the parameters theta, phi, and lambda.
func U(theta, phi, lambda float64) Gate {
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

	controlMask := 1 << (nQubits - 1 - control)

	for basis := controlMask; basis < size; basis += controlMask << 1 {
		targetBit := (basis >> (nQubits - 1 - target)) & 1
		targetState := basis ^ (1 << (nQubits - 1 - target))

		newGate[basis][basis] = gate.Matrix[targetBit][targetBit]
		newGate[basis][targetState] = gate.Matrix[targetBit][1-targetBit]
		newGate[targetState][basis] = gate.Matrix[1-targetBit][targetBit]
		newGate[targetState][targetState] = gate.Matrix[1-targetBit][1-targetBit]
	}

	return NewGate(newGate)
}

// Inverse returns the inverse (Hermitian transpose) of the gate.
func (gate *Gate) Inverse() Gate {
	rows := len(gate.Matrix)
	cols := len(gate.Matrix[0])
	inverseMatrix := make([][]complex128, cols) // Note that rows and cols are swapped.

	for i := range inverseMatrix {
		inverseMatrix[i] = make([]complex128, rows)
		for j := range inverseMatrix[i] {
			// Taking the complex conjugate and transposing the matrix.
			inverseMatrix[i][j] = cmplx.Conj(gate.Matrix[j][i])
		}
	}

	return NewGate(inverseMatrix)
}

// Multiply multiplies a matrix by a vector and returns the resulting vector.
func Multiply(matrix [][]complex128, vector []complex128) []complex128 {
	result := make([]complex128, len(matrix))

	for i, row := range matrix {
		for j, value := range row {
			result[i] += value * vector[j]
		}
	}

	return result
}

// IdentityMatrix creates and returns an identity matrix of size n x n.
func IdentityMatrix(n int) [][]complex128 {
	identity := make([][]complex128, n)

	for i := range identity {
		identity[i] = make([]complex128, n)
		identity[i][i] = 1
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
			// Extract common multiplicative factor
			m1Factor := m1[i][j]

			// Compute the base index for the row and column in the resulting matrix
			baseRow, baseCol := i*rowsM2, j*colsM2

			for k := 0; k < rowsM2; k++ {
				rowIdx := baseRow + k

				for l := 0; l < colsM2; l++ {
					colIdx := baseCol + l
					p[rowIdx][colIdx] = m1Factor * m2[k][l]
				}
			}
		}
	}

	return p
}
