# FormalSpec project environments: `use fspec` in an .envrc next to dev.star.
use_fspec() {
  watch_file dev.star fspec.lock
  local out
  out=$(fspec dev export --dir "$PWD") || return 1
  eval "$out"
}
