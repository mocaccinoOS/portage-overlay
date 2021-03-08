BACKEND?=docker
CONCURRENCY?=1
CI_ARGS?=
PACKAGES?=
GEN_PACKAGE_FILE?=packages.yaml

# Abs path only. It gets copied in chroot in pre-seed stages
export LUET?=/usr/bin/luet
export ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
DESTINATION?=$(ROOT_DIR)/build
COMPRESSION?=gzip
CLEAN?=false
export COMMON_TREE?=${ROOT_DIR}/multi-arch/packages
export TREE?=$(ROOT_DIR)/amd64/packages
#REPO_CACHE?=quay.io/mocaccinocache/portage-amd64-cache
REPO_CACHE?=quay.io/geaaru/portage-amd64-cache
export REPO_CACHE
BUILD_ARGS?=--pull --no-spinner
SUDO?=
VALIDATE_OPTIONS?=-s
ARCH?=amd64

ifneq ($(strip $(REPO_CACHE)),)
	BUILD_ARGS+=--image-repository $(REPO_CACHE)
endif

.PHONY: all
all: deps build

.PHONY: deps
deps:
	@echo "Installing luet"
	go get -u github.com/mudler/luet
	go get -u github.com/MottainaiCI/mottainai-cli

.PHONY: clean
clean:
	$(SUDO) rm -rf build/ *.tar *.metadata.yaml

.PHONY: build
build: clean
	mkdir -p $(ROOT_DIR)/build
	$(SUDO) $(LUET) build $(BUILD_ARGS) --tree=$(COMMON_TREE) --tree=$(TREE) $(PACKAGES) --destination $(ROOT_DIR)/build --backend $(BACKEND) --concurrency $(CONCURRENCY) --compression $(COMPRESSION)

.PHONY: build-all
build-all: clean
	mkdir -p $(ROOT_DIR)/build
	$(SUDO) $(LUET) build $(BUILD_ARGS) --tree=$(COMMON_TREE) --tree=$(TREE) --full --destination $(ROOT_DIR)/build --backend $(BACKEND) --concurrency $(CONCURRENCY) --compression $(COMPRESSION)

.PHONY: rebuild
rebuild:
	$(SUDO) $(LUET) build $(BUILD_ARGS) --tree=$(COMMON_TREE) --tree=$(TREE) $(PACKAGES) --destination $(ROOT_DIR)/build --backend $(BACKEND) --concurrency $(CONCURRENCY) --compression $(COMPRESSION)

.PHONY: rebuild-all
rebuild-all:
	$(SUDO) $(LUET) build $(BUILD_ARGS) --tree=$(COMMON_TREE) --tree=$(TREE) --full --destination $(ROOT_DIR)/build --backend $(BACKEND) --concurrency $(CONCURRENCY) --compression $(COMPRESSION)

.PHONY: create-repo
create-repo:
	$(SUDO) $(LUET) create-repo --tree "$(TREE)" --tree "$(COMMON_TREE)" \
    --output $(DESTINATION) \
    --packages $(DESTINATION) \
    --name "mocaccino-portage" \
    --descr "Mocaccino Gentoo Portage $(ARCH)" \
    --urls "http://localhost:8000" \
    --tree-compression gzip \
    --tree-filename tree.tar \
    --meta-compression gzip \
    --type http

.PHONY: serve-repo
serve-repo:
	LUET_NOLOCK=true $(LUET) serve-repo --port 8000 --dir $(ROOT_DIR)/build

autobump:
	TREE_DIR=$(ROOT_DIR) $(LUET) autobump-github

validate:
	$(LUET)  tree validate --tree $(TREE) --tree=$(COMMON_TREE) $(VALIDATE_OPTIONS)

gen: gen-provides-all

gen-provides:
	./scripts/gen_provides.sh

gen-provides-all:
	./scripts/gen_provides_all.sh 
