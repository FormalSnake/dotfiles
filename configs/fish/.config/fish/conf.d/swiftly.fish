
# Added by swiftly (macOS only)
if test (uname) = Darwin
    if test -f "$HOME/.swiftly/env.fish"
        source "$HOME/.swiftly/env.fish"
    end
end