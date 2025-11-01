.PHONY: all install build server

all: install build server

install:
	cargo install mdbook --locked

build:
	cd ./book && mdbook build

server:
	cd ./book && mdbook serve -p 3000 -n 127.0.0.1 -o
