# Makefile to build, tag, and push all Docker images + start Docker Compose services

USERNAME = prabhasranjan0
DC = docker-compose -f ./volumes/docker-compose.yaml
NAMESPACE = bbazaar-prod-in
GITHUB_REGISTRY = https://npm.pkg.github.com/prabhasranjan0
RETRIES=3
DELAY=5

MICROSERVICE_DIRS = $(shell find microservices -maxdepth 1 -type d ! -path microservices)

FRONTEND_CERTS_DIR = bbazaar-k8s/minikube/0-frontend/certs

BACKEND_CERTS_DIR = bbazaar-k8s/minikube/1-gateway/certs


create-npmrc-all:
	@echo "📦 Creating .npmrc in all microservices..."
	@for dir in $(MICROSERVICE_DIRS); do \
		echo "➡️  Creating .npmrc in $$dir"; \
		echo "$(USERNAME):registry=$(GITHUB_REGISTRY)" > $$dir/.npmrc; \
		echo "//npm.pkg.github.com/:_authToken=$(NPM_TOKEN)" >> $$dir/.npmrc; \
	done
	@echo "✅ .npmrc created in all services."

# Format: path:name
SERVICES = \
    microservices/8-review-service:review \
    microservices/7-order-service:order \
    microservices/6-chat-service:chat \
    microservices/5-gig-service:gig \
    microservices/4-users-service:users \
    microservices/3-auth-service:auth \
    microservices/2-notification-service:notification \
    microservices/1-gateway-service:gateway \
    bbazaar-client:frontend

.PHONY: all build push up down logs clean-containers \
	core-services micro-services elasticsearch kibana \
	apply-minikube create-namespace delete-namespace \
	apply-all-client-app delete-all-client-app delete-everything \
	k8s-apply-ingress-class k8s-delete-ingress-class

all-images: build push

## Docker Compose Targets

build:
	@echo "🔨 Building Docker images..."
	@$(foreach service, $(SERVICES), \
		path=$(word 1,$(subst :, ,$(service))); \
		name=$(word 2,$(subst :, ,$(service))); \
		image=$(USERNAME)/bbazaar-$$name; \
		echo "➡️  Building $$image from $$path..."; \
		docker build -t $$image $$path || exit 1; \
		docker tag $$image $$image:stable; \
		echo "✅ Built $$image:stable"; \
	)

push:
	@echo "🚀 Pushing Docker images..."
	@$(foreach service, $(SERVICES), \
		name=$(word 2,$(subst :, ,$(service))); \
		image=$(USERNAME)/bbazaar-$$name; \
		echo "⬆️  Pushing $$image:stable..."; \
		docker push $$image:stable || exit 1; \
		echo "✅ Pushed $$image:stable"; \
	)

up: core-services kibana micro-services

down:
	@echo "🛑 Shutting down all services..."
	$(DC) down

elasticsearch:
	@echo "🔍 Starting Elasticsearch..."
	rm -rf volumes/docker-volumes
	@$(DC) up -d elasticsearch
	@echo "⏳ Waiting for Elasticsearch..."
	@until curl -s http://localhost:9200 >/dev/null 2>&1; do printf '.'; sleep 2; done
	@echo "✅ Elasticsearch is ready."

core-services:
	@echo "🚀 Starting core services..."
	$(DC) up -d redis mongodb mysql postgres rabbitmq apmServer

kibana:
	@echo "📊 Starting Kibana..."
	$(DC) up -d kibana

micro-services:
	@echo "⚙️ Starting microservices..."
	$(DC) up -d review order chat gig users auth notifications gateway

## Kubernetes Targets

apply-minikube:
	minikube start --memory=8192 --cpus=6

create-namespace:
	kubectl create namespace $(NAMESPACE)

delete-namespace:
	kubectl delete namespace $(NAMESPACE)

define apply_k8s
$1-apply:
	@echo "📦 Deploying $1..."
	kubectl apply -f ./bbazaar-k8s/minikube/$2
endef

define delete_k8s
$1-delete:
	@echo "🗑️ Deleting $1..."
	kubectl delete -f ./bbazaar-k8s/minikube/$2 --ignore-not-found --wait=false
endef

define RETRY_MAKE
@i=0; \
until [ $$i -ge $(RETRIES) ]; do \
	echo "🔄 Attempt $$((i+1)) to run '$(1)'..."; \
	if $(MAKE) $(1); then \
		break; \
	else \
		echo "⚠️  '$(1)' failed. Retrying in $(DELAY) seconds..."; \
		i=$$((i+1)); \
		sleep $(DELAY); \
	fi; \
done; \
if [ $$i -eq $(RETRIES) ]; then \
	echo "❌ '$(1)' failed after $(RETRIES) attempts."; \
	exit 1; \
fi
endef

$(eval $(call apply_k8s,secrets,bbazaar-secrets))
$(eval $(call delete_k8s,secrets,bbazaar-secrets))

$(foreach svc,elasticsearch kibana mongo mysql postgresql redis queue,\
	$(eval $(call apply_k8s,$(svc),bbazaar-$(svc))))
$(foreach svc,elasticsearch kibana mongo mysql postgresql redis queue,\
	$(eval $(call delete_k8s,$(svc),bbazaar-$(svc))))

$(foreach svc,0-frontend 1-gateway 2-notifications 3-auth 4-users 5-gig 6-chat 7-order 8-reviews,\
	$(eval $(call apply_k8s,$(svc),$(svc))))
$(foreach svc,0-frontend 1-gateway 2-notifications 3-auth 4-users 5-gig 6-chat 7-order 8-reviews,\
	$(eval $(call delete_k8s,$(svc),$(svc))))

init: secrets-apply k8s-apply-ingress-class

wait-for-elasticsearch: elasticsearch-apply
	@echo "🔍 Setting up Elasticsearch..."
	@echo "⏳ Waiting for Elasticsearch..."
	@echo "Waiting for Elasticsearch pod to be ready (no timeout)..."
	@until kubectl get pods -l app=bbazaar-elastic -n $(NAMESPACE) -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' | grep -q "True"; do \
		echo "Still waiting..."; \
		sleep 5; \
	done
	@echo "✅ Elasticsearch pod is Ready!"

reset-kibana-password:
	@echo "Resetting Kibana system password..."
	@ELASTIC_POD_NAME=$$(kubectl get pods -n $(NAMESPACE) -l app=bbazaar-elastic -o jsonpath="{.items[0].metadata.name}"); \
	kubectl exec -n $(NAMESPACE) -it $$ELASTIC_POD_NAME -- \
		curl -s -X POST -u elastic:admin1234 \
		-H "Content-Type: application/json" \
		http://localhost:9200/_security/user/kibana_system/_password \
		-d '{"password": "kibana"}'

generate-service-token:
	echo "🔑 Generating unique Elasticsearch service token..."
	POD_NAME=$$(kubectl get pods -n $(NAMESPACE) -l app=bbazaar-elastic -o jsonpath="{.items[0].metadata.name}"); \
	TOKEN_NAME=bbazaar-kibana-$$RANDOM$$RANDOM; \
	echo "➡️ Creating token $$TOKEN_NAME..."; \
	kubectl exec -n $(NAMESPACE) -c bbazaar-elastic $$POD_NAME -- \
		/usr/share/elasticsearch/bin/elasticsearch-service-tokens create elastic/kibana $$TOKEN_NAME > token-output.txt; \
	TOKEN=$$(grep -o 'AAE[A-Za-z0-9_-]*' token-output.txt); \
	echo "Token: $$TOKEN"; \
	# Check if Kibana deployment exists, create it if necessary
	if ! kubectl get deployment bbazaar-kibana -n $(NAMESPACE) &>/dev/null; then \
		echo "➡️ Kibana deployment not found, creating..."; \
		kubectl apply -f bbazaar-k8s/minikube/bbazaar-kibana -n $(NAMESPACE); \
	fi; \
	# Patching the Kibana deployment with the new token
	echo "➡️ Patching Kibana deployment with new token..."; \
	kubectl patch deployment bbazaar-kibana -n $(NAMESPACE) \
		--type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/env/3/value", "value": "'"$$TOKEN"'"}]'; \
	rm -f token-output.txt; \
	echo "✅ Token applied to Kibana deployment."

core-services-apply: mongo-apply \
	mysql-apply postgresql-apply \
	redis-apply queue-apply

elasticdump-gigs:
	@echo "📥 Importing Gigs data into Elasticsearch via port-forward..."
	@PORT_FORWARD_CMD="kubectl port-forward svc/bbazaar-elastic 9200:9200 -n $(NAMESPACE)"; \
	echo "➡️ Starting port-forward..."; \
	$$PORT_FORWARD_CMD & \
	PF_PID=$$!; \
	sleep 5; \
	echo "➡️ Running elasticdump..."; \
	if ! elasticdump \
		--input=bbazaar-k8s/minikube/gigs/gigs.json \
		--output=http://elastic:admin1234@localhost:9200/gigs \
		--type=data; then \
		echo "❌ elasticdump failed"; \
		kill $$PF_PID; \
		exit 1; \
	fi; \
	echo "✅ Import complete. Cleaning up..."; \
	kill $$PF_PID


all-core-services:
	@echo "🚀 Starting full initialization sequence..."
	$(call RETRY_MAKE,init)
	@sleep $(DELAY)
	$(call RETRY_MAKE,wait-for-elasticsearch)
	@sleep $(DELAY)
	$(call RETRY_MAKE,reset-kibana-password)
	@sleep $(DELAY)
	$(call RETRY_MAKE,generate-service-token)
	@sleep $(DELAY)
	$(call RETRY_MAKE,core-services-apply)
	@sleep $(DELAY)
	$(call RETRY_MAKE,apply-all-client-app)
	@sleep $(DELAY)
	$(call RETRY_MAKE,elasticdump-gigs)
	@echo "✅ All steps completed successfully!"

core-services-delete: elasticsearch-delete kibana-delete \
	mongo-delete mysql-delete postgresql-delete \
	redis-delete queue-delete

apply-all-client-app: secrets-apply 0-frontend-apply \
	1-gateway-apply 2-notifications-apply 3-auth-apply 4-users-apply \
	5-gig-apply 6-chat-apply 7-order-apply 8-reviews-apply

delete-all-client-app: 0-frontend-delete \
	1-gateway-delete 2-notifications-delete 3-auth-delete 4-users-delete \
	5-gig-delete 6-chat-delete 7-order-delete \
	8-reviews-delete secrets-delete

k8s-apply-ingress-class:
	@echo "🌐 Installing ingress-nginx via Helm..."
	helm repo add ingress-nginx "https://kubernetes.github.io/ingress-nginx"
	helm repo update
	helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
		--namespace $(NAMESPACE) --create-namespace \
		--set controller.healthCheckPath="/healthz" \
		--set controller.containerPort.health=10254 \
		--set controller.livenessProbe.enabled=true \
		--set controller.readinessProbe.enabled=true \
		--set controller.image.tag="v1.9.5"
	@echo "✅ ingress-nginx installed or upgraded."

k8s-delete-ingress-class:
	@echo "🧹 Cleaning up ingress-nginx Helm release and related resources..."
	# Uninstall helm release (if it exists)
	-helm uninstall ingress-nginx --namespace ingress-nginx || true
	-helm uninstall ingress-nginx --namespace $(NAMESPACE) || true

	# Delete ingress-nginx namespace if desired
	-kubectl delete namespace ingress-nginx --ignore-not-found --wait=false
	-kubectl delete namespace $(NAMESPACE) --ignore-not-found --wait=false

	# Delete ClusterRoles and ClusterRoleBindings
	-kubectl delete clusterrole ingress-nginx --ignore-not-found --wait=false
	-kubectl delete clusterrolebinding ingress-nginx --ignore-not-found --wait=false

	# Delete any related deployments, services, or serviceaccounts (across all namespaces)
	-kubectl delete svc ingress-nginx-controller -n ingress-nginx --ignore-not-found --wait=false
	-kubectl delete deployment ingress-nginx-controller -n ingress-nginx --ignore-not-found --wait=false
	-kubectl delete sa ingress-nginx -n ingress-nginx --ignore-not-found --wait=false

	@echo "✅ All ingress-nginx and related Helm resources removed."

create-gateway-cert-secret:
	@echo "🔍 Checking for server certificate files in $(BACKEND_CERTS_DIR)..."
	@if [ -f "$(BACKEND_CERTS_DIR)/api.bbazaar.live.crt" ]; then \
		echo "✅ Found server certificate file: api.bbazaar.live.crt"; \
	else \
		echo "❌ Missing server certificate file: api.bbazaar.live.crt"; \
		exit 1; \
	fi
	@if [ -f "$(BACKEND_CERTS_DIR)/api.bbazaar.live.key" ]; then \
		echo "✅ Found key file: api.bbazaar.live.key"; \
	else \
		echo "❌ Missing server key file: api.bbazaar.live.key"; \
		exit 1; \
	fi
	@echo "🚀 Attempting to create Kubernetes TLS secret: gateway-ingress-tls"
	@kubectl -n $(NAMESPACE) create secret tls gateway-ingress-tls \
		--key $(BACKEND_CERTS_DIR)/api.bbazaar.live.key \
		--cert $(BACKEND_CERTS_DIR)/api.bbazaar.live.crt && \
		echo "✅ Successfully created TLS secret: gateway-ingress-tls" || \
		{ echo "⚠️  Failed to create TLS secret. It may already exist or there was an error."; exit 1; }


create-frontend-cert-secret:
	@echo "🔍 Checking for certificate files in $(FRONTEND_CERTS_DIR)..."
	@if [ -f "$(FRONTEND_CERTS_DIR)/bbazaar.com.crt" ]; then \
		echo "✅ Found certificate file: bbazaar.com.crt"; \
	else \
		echo "❌ Missing certificate file: bbazaar.com.crt"; \
		exit 1; \
	fi
	@if [ -f "$(FRONTEND_CERTS_DIR)/bbazaar.com.key" ]; then \
		echo "✅ Found key file: bbazaar.com.key"; \
	else \
		echo "❌ Missing key file: bbazaar.com.key"; \
		exit 1; \
	fi
	@echo "🚀 Attempting to create Kubernetes TLS secret: frontend-ingress-tls"
	@kubectl -n $(NAMESPACE) create secret tls frontend-ingress-tls \
		--key $(FRONTEND_CERTS_DIR)/bbazaar.com.key \
		--cert $(FRONTEND_CERTS_DIR)/bbazaar.com.crt && \
		echo "✅ Successfully created TLS secret: frontend-ingress-tls" || \
		{ echo "⚠️  Failed to create TLS secret. It may already exist or there was an error."; exit 1; }


delete-everything: delete-all-client-app core-services-delete delete-namespace

up-all:
	@echo "🚀 Starting full initialization sequence..."
	$(call RETRY_MAKE,apply-minikube)
	@sleep $(DELAY)
	$(call RETRY_MAKE,create-namespace)
	@echo "✅ Created minikube and namespace successfully!"
	@sleep $(DELAY)
	$(call RETRY_MAKE,all-core-services)
	@sleep $(DELAY)
	$(call RETRY_MAKE,create-gateway-cert-secret)
	@sleep $(DELAY)
	$(call RETRY_MAKE,create-frontend-cert-secret)
	@echo "✅ Completed all services successfully!"

remove-everything:
	@echo "🚀 Starting remove all services sequence..."
	$(call RETRY_MAKE,delete-all-client-app)
	@sleep $(DELAY)
	$(call RETRY_MAKE,core-services-delete)
	@sleep $(DELAY)
	$(call RETRY_MAKE,k8s-delete-ingress-class)
	@sleep $(DELAY)
	$(call RETRY_MAKE,delete-namespace)
	@echo "✅ All services removed and namespace completed successfully!"