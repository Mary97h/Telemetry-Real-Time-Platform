SHELL := /bin/bash

.PHONY: build up down logs test fmt

build:
\tdocker compose build

up:
\tdocker compose up -d

down:
\tdocker compose down -v

logs:
\tdocker compose logs -f

test:
\tcd apps/control-api && python -m venv .venv && . .venv/bin/activate && \\
\tpip install -r requirements.txt pytest && pytest -q

fmt:
\t@echo "Add linters/formatters here (ruff/black, mvn spotless:apply, etc.)"
