.PHONY: build test clean run

build:
	go build -o bin/quantum_simulator cmd/cli/cli.go

test:
	go test ./test/...

clean:
	rm -rf bin/

run: build
	./bin/quantum_simulator
