# iptables-http

Configure iptables to allow access to HTTP server and redirect external HTTP
port to app port.

# Requirements

This should be run after the `iptables` role, which sets `iptables_raw`.

# Role Variables

Port that app listens on
```yaml
iptables_http_app_port: 4001
```

HTTP public port
```yaml
iptables_http_external_port: 80
```

Whether to redirect external port to listen port
```yaml
iptables_http_redirect: true
```

Whether to rate limit inbound HTTP connections
```yaml
iptables_http_rate_limit: false
```

Rate limit options
```yaml
iptables_http_rate_limit_options: "-m hashlimit --hashlimit-name HTTP --hashlimit 5/minute --hashlimit-burst 10 --hashlimit-mode srcip --hashlimit-htable-expire 300000"
```

# Example Playbook

```yaml
- hosts: '*'
  roles:
     - { role: iptables-http, become: true }
```

# License

MIT

# Author Information

Jake Morrison <jake@cogini.com>
