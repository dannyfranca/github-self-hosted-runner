.PHONY: up down

workers ?= 2

up:
	COMPOSE_BAKE=true docker compose up -d --scale runner=${workers} --build

down:
	docker compose down
