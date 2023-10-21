package quantumsimulator

import (
	"fmt"
	"math"
	"math/cmplx"
	"strconv"
)

// Gate represents a quantum gate with a matrix representation
type Gate struct {
	Matrix [][]complex128
}

// NewGate creates a new Gate
func NewGate(matrix [][]complex128) Gate {
	return Gate{Matrix: matrix}
}

// Gates definitions
var (
	H = NewGate([][]complex128{
		{complex(1/math.Sqrt(2), 0), complex(1/math.Sqrt(2), 0)},
		{complex(1/math.Sqrt(2), 0), complex(-1/math.Sqrt(2), 0)},
	})

	X = NewGate([][]complex128{
		{complex(0, 0), complex(1, 0)},
		{complex(1, 0), complex(0, 0)},
	})

	T = NewGate([][]complex128{
		{complex(1, 0), complex(0, 0)},
		{complex(0, 0), cmplx.Exp(complex(0, math.Pi/4))},
	})
)

// Control applies a control gate
func (gate *Gate) Control(control, target, nQubits int) Gate {
	size := 1 << nQubits
	newGate := make([][]complex128, size)

	// Initializing the new gate as an identity matrix
	for i := range newGate {
		newGate[i] = make([]complex128, size)
		newGate[i][i] = 1
	}

	// Iterating over each basis state
	for basis := 0; basis < size; basis++ {
		basisBinary := fmt.Sprintf("%0*b", nQubits, basis)

		if basisBinary[control] == '1' {
			targetStateBinary := basisBinary[:target] +
				strconv.Itoa(1-int(basisBinary[target]-'0')) +
				basisBinary[target+1:]
			targetState, _ := strconv.ParseInt(targetStateBinary, 2, 0)

			// Applying the controlled operation
			newGate[basis][basis] = gate.Matrix[basisBinary[target]-'0'][basisBinary[target]-'0']
			newGate[basis][targetState] = gate.Matrix[basisBinary[target]-'0'][1-int(basisBinary[target]-'0')]
			newGate[targetState][basis] = gate.Matrix[1-int(basisBinary[target]-'0')][basisBinary[target]-'0']
			newGate[targetState][targetState] = gate.Matrix[1-int(basisBinary[target]-'0')][1-int(basisBinary[target]-'0')]
		}
	}

	return NewGate(newGate) // Returning the new controlled gate
}

// Multiply multiplies a matrix and vector
func Multiply(matrix [][]complex128, vector []complex128) []complex128 {
	rows := len(matrix)
	if len(matrix[0]) != len(vector) {
		return nil // Error: incompatible sizes for multiplication
	}

	result := make([]complex128, rows)
	for i := 0; i < rows; i++ {
		sum := complex128(0)
		for j := range vector {
			sum += matrix[i][j] * vector[j]
		}
		result[i] = sum
	}
	return result
}

// IdentityMatrix returns an identity matrix of size n
func IdentityMatrix(n int) [][]complex128 {
	identity := make([][]complex128, n)
	for i := range identity {
		identity[i] = make([]complex128, n)
		for j := range identity[i] {
			if i == j {
				identity[i][j] = 1 // Set diagonal elements to 1
			} else {
				identity[i][j] = 0 // Set off-diagonal elements to 0
			}
		}
	}
	return identity
}

// kronecker returns the Kronecker product of two matrices
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
