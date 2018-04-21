# Template for golang project locally or inside container
#
# Example usage:
# make BRANCH_NAME=${env.BRANCH_NAME} \
#		CHANGE_ID=${env.CHANGE_ID} \
#		BUILD_ID=${env.BUILD_ID} \
#		all
#
# For Debug, and display debug info:
# make debug DEBUG=1
#
# For console inside the build container
# make console


# look for whoami file, to pass user name across environments
WHOAMI_FILE=.whoami
ifneq ("$(wildcard $(WHOAMI_FILE))","")
include $(WHOAMI_FILE)
else
WHOAMI ?= $(shell whoami)
endif

# prep the golang cgo build environment to support static linking
DEBUG:=0
GOBUILD:=go build
ifeq ($(DEBUG),1)
GOBUILD:=go build -v -work -x -a
endif
GOCGO:=
GOCLEAN:=go clean
GOGET:=go get
GOINSTALL:=go install
GOTEST:=go test
GOVET:=go vet
GOTOOL:=go tool

# containerize
PWD := $(shell pwd)
NAME ?= $(shell basename $(PWD) | cut -f1 -d"@" | tr '[:upper:]' '[:lower:]')
DIST ?= golang
PKG := github.com/sysbot/$(NAME)
CONTAINER ?= $(NAME)-$(DIST)-builder
DOCKERFILE ?= ./build/Dockerfile.$(DIST).builder
OUTPUT := output
DOCKER_RUN_FLAGS :=--rm -v $$(pwd):/go/src/$(PKG) -w /go/src/$(PKG) $(CONTAINER)

# Expecting from build environment
VERSION_PREFIX := github.com/sysbot/$(NAME)/version
BRANCH_NAME := $(if $(BRANCH_NAME),$(BRANCH_NAME),development)
BUILD_ID := $(if $(BUILD_ID),$(BUILD_ID),99999)
BUILD_URL := $(if $(BUILD_URL),$(BUILD_URL),localhost)
EPOCH := $(if $(BUILD_TIME),$(BUILD_TIME),$(shell date "+%s"))
RUN_DISPLAY_URL := $(if $(RUN_DISPLAY_URL),$(RUN_DISPLAY_URL),localhost)

# extract from repo
AUTHOR :=$(shell git show --format="%an <%ae>" | head -1)
CHANGE :=$(shell git show --format="%s" | head -1)
DATE=$(shell date -d @$(EPOCH))
ISSUE_NAME :=$(shell git log -1 --pretty="%B" | head -1)
NOW := $(shell date -d @$(EPOCH) "+%Y%m%d-%H%M%S")
SHA := $(shell git rev-parse --short HEAD)
VERSION := $(shell date -d @$(EPOCH) "+%Y.%m.%d")
TAG := $(NAME)-$(BRANCH_NAME)-$(NOW)-$(SHA)
BINS := $(shell ls cmd)

ifeq ($(BRANCH_NAME),master)
BRANCH_NAME := $(BRANCH_NAME)
else ifeq ($(BRANCH_NAME),development)
BRANCH_NAME := $(BRANCH_NAME)
VERSION := $(shell date -d @$(EPOCH) "+%Y.%m.%d-%H%M%S")
else
BRANCH_NAME := pr$(CHANGE_ID)
VERSION := $(shell date -d @$(EPOCH) "+%Y.%m.%d-%H%M%S")
endif

define GO_LDFLAGS
'-X "$(VERSION_PREFIX).CurrentCommit=$(SHA)" \
-X "$(VERSION_PREFIX).Version=$(VERSION)" \
-X "$(VERSION_PREFIX).BuildID=$(BUILD_ID)" \
-X "$(VERSION_PREFIX).BuildTime=$(NOW)" \
-X "$(VERSION_PREFIX).Author=$(AUTHOR)" \
-X "$(VERSION_PREFIX).Tag=$(TAG)" \
-X "$(VERSION_PREFIX).Change=$(CHANGE)" \
-X "$(VERSION_PREFIX).CommitMsg=$(ISSUE_NAME)" \
-X "$(VERSION_PREFIX).OldBuildURL=$(BUILD_URL)" \
-X "$(VERSION_PREFIX).NewBuildURL=$(RUN_DISPLAY_URL)"'
endef

ifeq ($(DEBUG),1)
$(info $(BRANCH_NAME))
$(info $(BUILD_ID))
$(info $(BUILD_URL))
$(info $(EPOCH))
$(info $(EXPORTED))
$(info $(GOCGO))
$(info $(GO_LDFLAGS))
$(info $(NAME))
$(info $(RUN_DISPLAY_URL))
$(info $(WHOAMI))
endif

## build inside container and install
all: clean container-build

## run golang code fmt except for generated code and vendor
gofmt: ; @go fmt $$(go list ./... | grep -v /vendor/ )

## run dep ensure
dep: ; dep ensure

$(BINS):
	GOARCH=amd64 $(GOCGO) $(GOBUILD) -ldflags $(GO_LDFLAGS) -o $@ ./cmd/$@

## build binaries in cmd and dependent binaries
build: clean gofmt $(BINS)

## go vet the entire repo, skip checking for printf related errors
vet: ; $(GOVET) -v -printf=false ./...

## go tests the entire repo
test: ; $(GOTEST) -v ./...

## remove built binaries
clean:
	rm -rf $(OUTPUT)
	@$(foreach x,$(BINS),rm -f ./$(x);)

## build a container from the Dockerfile
container:
	@mkdir -p $(PWD)/$(OUTPUT)
	docker build -t $(CONTAINER) -f $(DOCKERFILE) .

## bash prgo test -coverprofile $(NAME)-cover.outompt inside the build container
console: container
	docker run -it $(DOCKER_RUN_FLAGS)

## build binaries inside of the build container
container-build: container
	docker run $(DOCKER_RUN_FLAGS) make install

## run test inside of container
container-test: container
	docker run $(DOCKER_RUN_FLAGS) make prep-install

## build and run
run: build
	./http

prep-install: dep test

local-install: ; go install ./...

cover:
	$(GOTEST) -coverprofile $(NAME)-cover.out
	$(GOTOOL) cover -html=$(NAME)-cover.out -o $(NAME)-cover.html
	open $(NAME)-cover.html

## rebuild and install binaries into OUTPUT directory
install: prep-install build
	@mkdir -p $(OUTPUT)
	@$(foreach x,$(BINS),cp ./$(x) $(OUTPUT);)

## restart mac os x system dnsmasq
dnsmasq: ; sudo ./scripts/cert.sh dns "$(NAME).$(WHOAMI)"

GREEN	 := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
WHITE	 := $(shell tput -Txterm setaf 7)
RESET	 := $(shell tput -Txterm sgr0)

TARGET_MAX_CHAR_NUM=20
## Show this help
help:
	@echo ''
	@echo 'Usage:'
	@echo '	 ${YELLOW}make${RESET} ${GREEN}<target>${RESET}'
	@echo ''
	@echo 'Targets:'
	@awk '/^[a-zA-Z\-\_0-9]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")-1); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "	${YELLOW}%-$(TARGET_MAX_CHAR_NUM)s${RESET} ${GREEN}%s${RESET}\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)

.PHONY: help
