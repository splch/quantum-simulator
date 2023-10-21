# Quantum Simulator in Go

[![PkgGoDev](https://pkg.go.dev/badge/github.com/splch/quantumsimulator)](https://pkg.go.dev/github.com/splch/quantumsimulator)
[![Go Report Card](https://goreportcard.com/badge/github.com/splch/quantumsimulator?style=flat-square)](https://goreportcard.com/report/github.com/splch/quantumsimulator)

## Introduction

A simple quantum simulator implemented in Go.

## Requirements

- Go 1.21 or higher

## Usage

To `get`:

```shell
go get github.com/splch/quantumsimulator
```

To `run`:

```shell
go run main.go -qubits 3 -shots 10 -ops "H:0,CX:0:1,U:2:0.2:0.3:0.4"
```

To `test`:

```shell
go test ./pkg/quantumsimulator/... -v
```

## Contributing

Feel free to contribute to this project. Open an issue or a pull request.

## License

MIT
