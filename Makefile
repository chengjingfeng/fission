# Copyright 2017 The Fission Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

.DEFAULT_GOAL := check

# Platforms to build in multi-architecture images.
PLATFORMS ?= linux/amd64,linux/arm64,linux/arm/v7

# Repository prefix and tag to push multi-architecture images to.
REPO ?= fission
TAG ?= dev

check: test-run build clean

# run basic check scripts
test-run:
	hack/verify-gofmt.sh
	hack/verify-govet.sh
	hack/verify-staticcheck.sh
	hack/runtests.sh
	@rm -f coverage.txt

# ensure the changes are buildable
build:
	go build -o cmd/fission-bundle/fission-bundle ./cmd/fission-bundle/
	go build -o cmd/fission-cli/fission ./cmd/fission-cli/
	go build -o cmd/fetcher/fetcher ./cmd/fetcher/
	go build -o cmd/fetcher/builder ./cmd/builder/
	go build -o cmd/reporter/reporter ./cmd/reporter/

# install CLI binary to $PATH
install-cli: build
	mv cmd/fission-cli/fission $(GOPATH)/bin

verify-builder:
	@./hack/buildx.sh

# build images (environment images are not included)
image:
	docker build -t fission-bundle -f cmd/fission-bundle/Dockerfile.fission-bundle .
	docker build -t fetcher -f cmd/fetcher/Dockerfile.fission-fetcher .
	docker build -t builder -f cmd/builder/Dockerfile.fission-builder .
	docker build -t reporter -f cmd/builder/Dockerfile.reporter .

# build multi-architecture images for release.
image-multiarch: verify-builder
	docker buildx build --platform=$(PLATFORMS) -t $(REPO)/fission-bundle:$(TAG) --push -f cmd/fission-bundle/Dockerfile.fission-bundle .
	docker buildx build --platform=$(PLATFORMS) -t $(REPO)/fetcher:$(TAG) --push -f cmd/fetcher/Dockerfile.fission-fetcher .
	docker buildx build --platform=$(PLATFORMS) -t $(REPO)/builder:$(TAG) --push -f cmd/builder/Dockerfile.fission-builder .
	docker buildx build --platform=$(PLATFORMS) -t $(REPO)/preupgradechecks:$(TAG) --push -f cmd/preupgradechecks/Dockerfile.fission-preupgradechecks .
	docker buildx build --platform=$(PLATFORMS) -t $(REPO)/reporter:$(TAG) --push -f cmd/reporter/Dockerfile.reporter .

multiarch-bundle: verify-builder
	docker buildx build --platform=$(PLATFORMS) -t $(REPO)/fission-bundle:$(TAG) --push -f cmd/fission-bundle/Dockerfile.fission-bundle .

multiarch-fetcher: verify-builder
	docker buildx build --platform=$(PLATFORMS) -t $(REPO)/fetcher:$(TAG) --push -f cmd/fetcher/Dockerfile.fission-fetcher .

multiarch-builder: verify-builder
	docker buildx build --platform=$(PLATFORMS) -t $(REPO)/builder:$(TAG) --push -f cmd/builder/Dockerfile.fission-builder .

multiarch-preupgrade: verify-builder
	docker buildx build --platform=$(PLATFORMS) -t $(REPO)/pre-upgrade-checks:$(TAG) --push -f cmd/preupgradechecks/Dockerfile.fission-preupgradechecks . 

multiarch-reporter: verify-builder
	docker buildx build --platform=$(PLATFORMS) -t $(REPO)/reporter:$(TAG) --push -f cmd/reporter/Dockerfile.reporter .

generate-crds:
	controller-gen crd:trivialVersions=false,preserveUnknownFields=false  paths=./pkg/apis/core/v1  output:crd:artifacts:config=crds/v1

create-crds:
	@kubectl create -k crds/v1

update-crds:
	@kubectl replace -k crds/v1

delete-crds:
	@./hack/delete-crds.sh

clean:
	@rm -f cmd/fission-bundle/fission-bundle
	@rm -f cmd/fission-cli/fission
	@rm -f cmd/fetcher/fetcher
	@rm -f cmd/fetcher/builder
	@rm -f cmd/reporter/reporter
