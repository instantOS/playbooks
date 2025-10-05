default:
    just --choose

install:
    ansible-galaxy install -r requirements.yml --force

format:
    bunx prettier --write "**/*.yml"

lint:
    yamllint .
    ansible-lint main.yml --exclude .ansible

