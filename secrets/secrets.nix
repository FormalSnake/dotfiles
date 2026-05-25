# agenix recipient map. Used by the `agenix` CLI when re-encrypting.
#
# Add a new public key here to grant it decrypt access to all listed secrets,
# then run `agenix -r` from the secrets/ dir to re-encrypt to the new recipient set.

let
  kyan = "age1fg5dvcv49wmf6dz4zdan6yyvqfc6wangmlc0ff3rfwwuphy2fsfsk3hufv";
in
{
  "openai.age".publicKeys             = [ kyan ];
  "anthropic.age".publicKeys          = [ kyan ];
  "gemini.age".publicKeys             = [ kyan ];
  "deepseek.age".publicKeys           = [ kyan ];
  "nucleo-license.age".publicKeys     = [ kyan ];
  "npm-github-token.age".publicKeys   = [ kyan ];
  "npm-registry-token.age".publicKeys = [ kyan ];
}
