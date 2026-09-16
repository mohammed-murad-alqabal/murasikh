# Production TLS certificates

Place the certificate files supplied by the certificate authority in this directory:

- `fullchain.pem`
- `privkey.pem`

The files are intentionally ignored by Git (`*.pem`, `*.key`). Do not commit private keys. The production Compose file mounts this directory read-only into Nginx.
