# Who each secret is encrypted to, agenix's secrets.nix. After changing a recipient run
# `fspec secret rekey`; `fspec secret edit <name>` creates or changes one.

kyan = "age1fg5dvcv49wmf6dz4zdan6yyvqfc6wangmlc0ff3rfwwuphy2fsfsk3hufv"

# Exported by fish under these names (modules/secrets.star writes the conf.d file).
ENV = {
    "openai": "OPENAI_API_KEY",
    "gemini": "GEMINI_API_KEY",
    "deepseek": "DEEPSEEK_API_KEY",
    "nucleo-license": "NUCLEO_LICENSE_KEY",
    "npm-github-token": "NPM_GITHUB_TOKEN",
    "npm-registry-token": "NPM_REGISTRY_TOKEN",
    "wstunnel-path-prefix": "WSTUNNEL_PATH_PREFIX",
    "wstunnel-endpoint": "WSTUNNEL_ENDPOINT",
}

# Read from their files only. anthropic stays out of the shell: Claude Code prefers an
# ANTHROPIC_API_KEY over the claude.ai login and bills the API.
FILES = ["anthropic", "couchdb-admin", "lastfm-api-key", "livesync-passphrase"]

secrets = {"secrets/%s.age" % n: [kyan] for n in list(ENV) + FILES}
