# Make `npm install -g packagename` install into `~/.node_modules/bin`.
#
# This also makes yarn install into that path via `yarn global add
# packagename`. Yarn also puts bins here, since it knows
# $npm_config_prefix.
#
set -gx npm_config_prefix ~/.node_modules

# Add the path to your executable paths.
if test -d ~/.node_modules/bin
  set -gx fish_user_paths ~/.node_modules/bin $fish_user_paths
end

# Might as well get Yarn's, too.
if test -d ~/.yarn/bin
  set -gx fish_user_paths ~/.yarn/bin $fish_user_paths
end

# Troubleshooting
# ---------------
#
# Inspect your yarn and npm config:
#
#     $ yarn global dir
#       /home/yourname/.config/yarn/global
#
#     $ yarn config get prefix
#       /home/yourname/.node_modules
#
#     $ npm config get prefix
#       /home/yourname/.node_modules
#
# If not, set it:
#
#     $ npm config set prefix /home/yourname/.node_modules
#     $ yarn config set prefix /home/yourname/.node_modules
