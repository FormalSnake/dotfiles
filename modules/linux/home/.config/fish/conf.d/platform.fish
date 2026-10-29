# environment.d/10-session.conf sets the same ones for the systemd user session;
# fish needs them for ssh and mosh logins.
set -gx BROWSER helium
set -gx GSK_RENDERER gl
set -gx GTK2_RC_FILES ~/.gtkrc-2.0
set -gx HYPRCURSOR_SIZE 24
set -gx HYPRCURSOR_THEME Bibata-Modern-Classic
set -gx XCURSOR_SIZE 24
set -gx XCURSOR_THEME Bibata-Modern-Classic
set -gx FZF_DEFAULT_OPTS '--color bg:#100F0F,bg+:#1C1B1A,border:#AF3029,fg:#878580,fg+:#878580,gutter:#100F0F,header:#CECDC3,hl:#CECDC3,hl+:#CECDC3,info:#24837B,marker:#AF3029,pointer:#AD8301,prompt:#AD8301,separator:#1C1B1A,spinner:#24837B'

# OpenSSH 10.1+ unlinks a forwarded agent socket when its ssh session ends, which mosh's
# bootstrap ssh does right after starting mosh-server. A dead socket falls back to the local
# gcr agent, whose key every host accepts; a live forwarded one is kept.
if not test -S "$SSH_AUTH_SOCK"; and test -S "$XDG_RUNTIME_DIR/gcr/ssh"
    set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/gcr/ssh"
end

status is-interactive; and fish_config theme choose "Flexoki Dark"
