# AGENTS.md - Ansible Playbook Development Guide

## Build/Lint/Test Commands

```bash
# Install dependencies
just install

# Format YAML files
just format

# Lint playbooks and roles
just lint

# Run specific playbook
ansible-playbook -i inventory playbook.yml

# Check mode (dry run)
ansible-playbook -i inventory playbook.yml --check

# Run with specific tags
ansible-playbook -i inventory playbook.yml --tags tag_name
```

## Code Style Guidelines

### YAML Structure
- Use 2 spaces for indentation (never tabs)
- Use `---` at start of files
- Quote strings with special characters
- Use consistent list formatting (dash + space)

### Ansible Conventions
- Use descriptive task names (start with capital letter)
- Group related tasks with comments
- Use `become: yes` for privilege escalation
- Prefer `ansible.builtin` modules over community modules when possible
- Use `state: present` for idempotency
- Include `notify` for handlers when services need restart

### Variable Naming
- Use snake_case for variable names
- Prefix role-specific variables with role name
- Use descriptive names (e.g., `caddy_confd_dir` not `dir`)

### File Organization
- Keep roles in `roles/` directory
- Use `defaults/main.yml` for default variables
- Use `vars/main.yml` for required variables
- Use `handlers/main.yml` for service handlers
- Use `templates/` for Jinja2 templates (.j2 extension)
- Use `files/` for static files

### Error Handling
- Use `failed_when: false` only when necessary
- Include proper error messages in `name` fields
- Use `ignore_errors: yes` sparingly with justification
- Test playbooks in check mode before applying

### Security
- Never commit secrets to repository
- Use Ansible Vault for sensitive data
- Use `no_log: true` for tasks with sensitive output
- Validate user input in templates