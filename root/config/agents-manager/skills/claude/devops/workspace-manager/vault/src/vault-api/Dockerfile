FROM node:22-alpine

WORKDIR /app

# Runtime env — defaults here as safety net; docker-compose overrides at container start
ENV MASTER_ROOT_SEAL="dev-root-seal-do-not-use-in-production"
ENV VAULT_MODE=root
ENV VAULT_ANC_DIR=/opt/vault/anc
ENV VAULT_SEAL_DIR=/opt/vault/seals
ENV VAULT_DB_HOST=vault-postgres
ENV VAULT_DB_PORT=5432
ENV VAULT_DB_NAME=vaultdb
ENV VAULT_DB_USER=vaultuser

COPY package*.json ./
RUN npm install

COPY tsconfig.json ./
COPY src ./src
RUN npm run build

EXPOSE 8443
CMD ["node", "dist/app.js"]
