FROM node:22-bookworm-slim

RUN apt-get update \
    && apt-get install --yes --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN npm install --global \
        @anthropic-ai/claude-code \
        @openai/codex \
        @google/gemini-cli \
    && npm cache clean --force

RUN useradd --create-home --shell /bin/sh agent \
    && mkdir /workspace \
    && chown agent:agent /workspace

USER agent
WORKDIR /workspace
