.PHONY: setup bootstrap ssh clean help

help:
	@echo "Available commands:"
	@echo "  make setup      - Copy .env.example to .env if it does not exist"
	@echo "  make bootstrap  - Run the homelab server bootstrap initiator script"
	@echo "  make ssh        - SSH into the configured target server"

setup:
	@if [ ! -f .env ]; then \
		echo "[+] Copying .env.example to .env..."; \
		cp .env.example .env; \
		echo "[+] Please edit the values in .env to match your server details."; \
	else \
		echo "[+] .env file already exists."; \
	fi

bootstrap: setup
	@bash ./scripts/bootstrap.sh

ssh:
	@if [ -f .env ]; then \
		export $$(grep -v '^#' .env | xargs) && \
		ssh -i "$${SSH_KEY_PATH/#\~/\$$HOME}" "$$SERVER_USER@$$SERVER_IP"; \
	else \
		echo "[-] Error: .env file not found. Run 'make setup' first."; \
		exit 1; \
	fi
