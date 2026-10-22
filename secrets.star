# Recipients of each secret, the counterpart of agenix's secrets.nix. Add a public key here, then
# run `fspec secret rekey` to re-encrypt every file to the new set.

kyan = "age1fg5dvcv49wmf6dz4zdan6yyvqfc6wangmlc0ff3rfwwuphy2fsfsk3hufv"

secrets = {
    "secrets/" + name + ".age": [kyan]
    for name in ["openai", "anthropic", "gemini", "deepseek", "nucleo-license", "npm-github-token",
                 "npm-registry-token", "wstunnel-path-prefix", "wstunnel-endpoint", "couchdb-admin",
                 "lastfm-api-key", "livesync-passphrase"]
}
