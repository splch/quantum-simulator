package quantum_simulator

import (
	"math"
	"math/cmplx"
)

type Gate struct {
	Matrix []complex128
}

var (
	H = Gate{
		Matrix: []complex128{
			1 / cmplx.Sqrt(2), 1 / cmplx.Sqrt(2),
			1 / cmplx.Sqrt(2), -1 / cmplx.Sqrt(2),
		},
	}
	T = Gate{
		Matrix: []complex128{
			1, 0,
			0, cmplx.Exp(complex(0, 1) * math.Pi / 4),
		},
	}
	X = Gate{
		Matrix: []complex128{
			0, 1,
			1, 0,
		},
	}
)

func ApplyGate(state []complex128, gate Gate, qubit int) {
	// Implementation here
}
