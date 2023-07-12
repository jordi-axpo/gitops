.DEFAULT_GOAL := help
SHELL := /usr/bin/env bash
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables

.PHONY: flux-ui help init

cluster-staging-create: init # create a local staging cluster with kind and sync with flux
	kind create cluster --name staging --config kind/staging.yaml
	kubectl cluster-info --context kind-staging
	source .envrc
	flux bootstrap github \
		--context=kind-staging \
		--owner=${GITHUB_USER} \
		--repository=${GITHUB_REPO} \
		--branch=main \
		--personal \
		--path=clusters/staging
	watch flux get helmreleases --all-namespaces

cluster-staging-delete: init # deletes the local staging cluster
	kind delete cluster --name staging

flux-ui: init ## port-forward to the current kubernetes cluster so flux UI can be accessed in http://localhost:9001
	kubectl -n flux-system port-forward svc/weave-gitops 9001:9001

help: ## list available commands
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## verify that all the required commands are already installed
	@if [ -z "$$CI" ]; then \
		function cmd { \
			if ! command -v "$$1" &>/dev/null ; then \
				echo "error: missing required command in PATH: $$1" >&2 ;\
				return 1 ;\
			fi \
		} ;\
		cmd flux ;\
		cmd kind ;\
		cmd kubeconform ;\
		cmd kubectl ;\
	fi

validate: init # validate the flux custom resources and kustomize overlays using kubeconform
	./scripts/validate.sh
