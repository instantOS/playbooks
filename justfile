default:
    just --choose

install:
    ansible-galaxy install -r requirements.yml --force

format:
    bunx prettier --write "**/*.yml"

lint:
    yamllint .
    ansible-lint axolotl.yml capybara.yml chungus.yml goose.yml turtle.yml --exclude .ansible
