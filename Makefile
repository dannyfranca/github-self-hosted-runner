.PHONY: up down build-multi

workers ?= 1

up:
	COMPOSE_BAKE=true docker compose up -d --scale runner=${workers} --build

down:
	docker compose down
