APP_DIR = my-app
CLUSTER = demo
CONTAINER_CMD = docker
COSIGN_PASSWORD = ""
IMAGE_REGISTRY = ttl.sh
# IMAGE_NAME = blake-demo-unsigned
IMAGE_NAME = blake-demo-signed
IMAGE_TAG = 1h
KUBE_NAMESPACE = default

KUBE_CONTEXT = kind-$(CLUSTER)
IMAGE_DIGEST = $(shell $(CONTAINER_CMD) image inspect --format='{{index .RepoDigests 0}}' $(IMAGE_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG))

all: cluster $(SERVICES)

info:
	@echo APP_DIR = $(APP_DIR)
	@echo CLUSTER = $(CLUSTER)
	@echo CONTAINER_CMD = $(CONTAINER_CMD)
	@echo COSIGN_PASSWORD = $(COSIGN_PASSWORD)
	@echo IMAGE_DIGEST = $(IMAGE_DIGEST)
	@echo IMAGE_NAME = $(IMAGE_NAME)
	@echo IMAGE_REGISTRY = $(IMAGE_REGISTRY)
	@echo IMAGE_TAG = $(IMAGE_TAG)
	@echo KUBE_CONTEXT = $(KUBE_CONTEXT)

install:
	brew install cosign

create-cluster:
	-kind create cluster --name $(CLUSTER)

delete-cluster:
	kind delete cluster --name $(CLUSTER)

apply-cluster:
	kubectl apply -R -f cluster

generate-key-pair:
	COSIGN_PASSWORD=$(COSIGN_PASSWORD) cosign generate-key-pair

generate:
	cosign generate $(IMAGE_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)

build-app:
	@echo "building $(IMAGE_NAME)"
	$(CONTAINER_CMD) build -t $(IMAGE_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) ./$(APP_DIR)

sign-app: build-app push-app
	COSIGN_PASSWORD=$(COSIGN_PASSWORD) cosign sign --key cosign.key $(IMAGE_DIGEST)

save:
	cosign save $(IMAGE_DIGEST) --dir sig

verify:
	cosign verify --key cosign.pub $(IMAGE_DIGEST)

download-signature:
	@cosign download signature $(IMAGE_DIGEST)

push-app:
	@echo "pushing $(IMAGE_REGISTRY)/$(IMAGE_NAME)"
	# kind load docker-image $(IMAGE_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) --name $(CLUSTER)
	$(CONTAINER_CMD) push $(IMAGE_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)

deploy-app:
	@echo "deploying $(APP_DIR)"
	kubectl apply --context $(KUBE_CONTEXT) --namespace $(KUBE_NAMESPACE) -R -f $(APP_DIR)/_k8s
	kubectl rollout restart --context $(KUBE_CONTEXT) -f $(APP_DIR)/_k8s/deployment.yaml

delete-app:
	@echo "removing app"
	kubectx $(KUBE_CONTEXT)
	kubectl delete --namespace $(KUBE_NAMESPACE) -R -f $(APP_DIR)/_k8s

install-kyverno:
	# https://kyverno.io/docs/installation/
	helm repo add kyverno https://kyverno.github.io/kyverno/
	helm repo update
	helm install kyverno kyverno/kyverno -n kyverno --create-namespace --kube-context $(KUBE_CONTEXT)

logs-app:
	stern --context $(KUBE_CONTEXT) .*

uuid:
	@uuidgen | tr "[:upper:]" "[:lower:]"

.PHONY : all cluster logs-app push-app verify save sign-app build-app generate deploy-app
