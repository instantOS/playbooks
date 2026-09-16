# playbooks

Ansible-playbooks for instantOS servers


## Bifrost on axolotl

The `bifrost` role runs the gateway through the Freiburg FortiVPN and exposes
only `https://bifrost.paperbenni.xyz` through Caddy. The container port is bound
to loopback; Bifrost's own authentication protects both its dashboard and API.

Add these values to `secrets.yml` with `ansible-vault edit secrets.yml` before
deploying:

```yaml
bifrost_vpn_user: your-vpn-user
bifrost_vpn_password: your-vpn-password
bifrost_admin_username: admin
bifrost_admin_password: a-long-random-password
bifrost_encryption_key: a-stable-random-secret-of-at-least-32-characters
```

No certificate setup is needed: the VPN gateway certificate validates
against the container's system CA store. Only if the gateway ever stops
validating (e.g. a private CA) set the optional pin
`bifrost_vpn_trusted_cert` to the gateway certificate's sha256 digest.

(Bifrost pinned, openfortivpn tracking `latest`).

The encryption key must remain stable after Bifrost has stored credentials.
Deploy just this service with:

```bash
ansible-playbook axolotl.yml --tags bifrost
```
