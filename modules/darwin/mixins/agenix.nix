{ inputs, ... }:
{
  imports = [ inputs.agenix.darwinModules.default ];

  age = {
    # Master identity used to decrypt at activation time.
    identityPaths = [ "/Users/kyandesutter/.config/age/keys.txt" ];

    secrets =
      let
        mkSecret = name: {
          file = ../../../secrets/${name}.age;
          owner = "kyandesutter";
          group = "staff";
        };
      in
      {
        openai             = mkSecret "openai";
        anthropic          = mkSecret "anthropic";
        gemini             = mkSecret "gemini";
        deepseek           = mkSecret "deepseek";
        canaryllm          = mkSecret "canaryllm";
        nucleo-license     = mkSecret "nucleo-license";
        npm-github-token   = mkSecret "npm-github-token";
        npm-registry-token = mkSecret "npm-registry-token";
      };
  };
}
