package quantumsimulator

import (
	"math"
	"math/cmplx"
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
	controlledMatrix := [][]complex128{
		{complex(1, 0), complex(0, 0), complex(0, 0), complex(0, 0)},
		{complex(0, 0), complex(1, 0), complex(0, 0), complex(0, 0)},
		{complex(0, 0), complex(0, 0), gate.Matrix[0][0], gate.Matrix[0][1]},
		{complex(0, 0), complex(0, 0), gate.Matrix[1][0], gate.Matrix[1][1]},
	}
	return NewGate(controlledMatrix)
}
