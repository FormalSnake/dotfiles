eval "$(/opt/homebrew/bin/brew shellenv)"
set -U fish_greeting
set -U fish_key_bindings fish_vi_key_bindings
set -U fish_cursor_default
set -Ux EDITOR nvim
set -Ux fish_color_autosuggestion normal

alias add="git add"
alias commit="git commit"
alias pull="git pull"
alias stat="git status"
alias gdiff="git diff HEAD"
alias vdiff="git difftool HEAD"
alias log="git log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
alias cfg="git --git-dir=$HOME/dotfiles/ --work-tree=$HOME"
alias push="git push"
alias g="lazygit"
alias quote="~/quote.sh"
alias benchmark="~/tb.sh"
alias rmf="rm -rf"
alias nograph="python3 -m notion_graph -p 607bb0093c714cb0999bd0ce7f2afe71 -t secret_4IQB8Xw98zZrRVFAj0JBIuKQx3KOvtZGrMcoZQMSnkY -o ./Documents/nograph/graph_out.html"

# Base16 Shell
if status --is-interactive
    set BASE16_SHELL_PATH "$HOME/.config/base16-shell"
    set BASE16_SHELL "$HOME/.config/base16-shell"
    if test -s "$BASE16_SHELL_PATH"
        source "$BASE16_SHELL_PATH/profile_helper.fish"
    end
end
zoxide init fish | source
starship init fish | source
neofetch
quote
