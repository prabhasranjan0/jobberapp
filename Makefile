# Makefile to build, tag, and push all Docker images + start Docker Compose services

USERNAME = prabhasranjan0
DC = docker-compose -f ./volumes/docker-compose.yaml
NAMESPACE = production
GITHUB_REGISTRY = https://npm.pkg.github.com/prabhasranjan0

MICROSERVICE_DIRS = $(shell find microservices -maxdepth 1 -type d ! -path microservices)

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
    jobber-client:frontend

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
		image=$(USERNAME)/jobber-$$name; \
		echo "➡️  Building $$image from $$path..."; \
		docker build -t $$image $$path || exit 1; \
		docker tag $$image $$image:stable; \
		echo "✅ Built $$image:stable"; \
	)

push:
	@echo "🚀 Pushing Docker images..."
	@$(foreach service, $(SERVICES), \
		name=$(word 2,$(subst :, ,$(service))); \
		image=$(USERNAME)/jobber-$$name; \
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
	minikube start --memory=max --cpus=max

create-namespace:
	kubectl create namespace $(NAMESPACE)

delete-namespace:
	kubectl delete namespace $(NAMESPACE)

define apply_k8s
$1-apply:
	@echo "📦 Deploying $1..."
	kubectl apply -f ./jobber-k8s/minikube/$2
endef

define delete_k8s
$1-delete:
	@echo "🗑️ Deleting $1..."
	kubectl delete -f ./jobber-k8s/minikube/$2
endef

$(eval $(call apply_k8s,secrets,jobber-secrets))
$(eval $(call delete_k8s,secrets,jobber-secrets))

$(foreach svc,elasticsearch kibana mongo mysql postgresql redis queue,\
	$(eval $(call apply_k8s,$(svc),jobber-$(svc))))
$(foreach svc,elasticsearch kibana mongo mysql postgresql redis queue,\
	$(eval $(call delete_k8s,$(svc),jobber-$(svc))))

$(foreach svc,0-frontend 1-gateway 2-notifications 3-auth 4-users 5-gig 6-chat 7-order 8-reviews,\
	$(eval $(call apply_k8s,$(svc),$(svc))))
$(foreach svc,0-frontend 1-gateway 2-notifications 3-auth 4-users 5-gig 6-chat 7-order 8-reviews,\
	$(eval $(call delete_k8s,$(svc),$(svc))))

init: secrets-apply k8s-apply-ingress-class

core-services-apply: kibana-apply mongo-apply \
	mysql-apply postgresql-apply \
	redis-apply queue-apply

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
	  --namespace $(NAMESPACE) --create-namespace
	@echo "✅ ingress-nginx installed or upgraded."

k8s-delete-ingress-class:
	@echo "🗑️ Uninstalling ingress-nginx from namespace $(NAMESPACE)..."
	helm uninstall ingress-nginx --namespace $(NAMESPACE)
	@echo "✅ ingress-nginx has been uninstalled."

delete-everything: delete-all-client-app core-services-delete delete-namespace
