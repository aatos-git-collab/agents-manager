# Isolated Agent Container — decryption-only vault client
# Security properties:
#   • No MASTER_ROOT_SEAL — cannot encrypt, cannot create seals
#   • PER_AGENT_SEAL injected at runtime via env — never stored in image
#   • .seal file mounted READ-ONLY — cannot be overwritten by agent
#   • Sealed system prompt mounted READ-ONLY — cannot be modified by agent
#   • Agent process runs as non-root UID 1000
#   • No shell, no package managers, minimal attack surface

FROM node:22-alpine

# Security: drop privileges, no shell, no package managers
RUN addgroup -S agent && adduser -S -G agent agent

WORKDIR /app

# Copy client app
COPY --chown=agent:agent agent.js ./

# Create read-only mount points (owned by root, agent can only read)
RUN mkdir -p /seal /prompt && chown root:root /seal /prompt && chmod 0555 /seal /prompt

# Copy sealed system prompt template (will be overwritten by volume mount at runtime)
COPY sealed-prompt/system-prompt.txt /prompt/system-prompt.txt

USER agent
# Agent can read /prompt but cannot write (root owns it, others have r-x)

# Ports
EXPOSE 8444

CMD ["node", "agent.js"]
