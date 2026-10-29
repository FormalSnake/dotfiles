function gpull --description="Git pull (rebase) from origin; launch Claude Code on merge conflicts"
    if test -n "$argv[1]"
        set branch_name $argv[1]
    else
        set branch_name (git rev-parse --abbrev-ref HEAD)
    end

    git pull --rebase origin $branch_name
    and return 0

    set conflicts (git diff --name-only --diff-filter=U)
    if test -z "$conflicts"
        return 1
    end

    echo "Merge conflicts detected: launching Claude Code…"
    set prompt (printf '%s\n' "Fix the following merge errors:" $conflicts | string collect)
    claude $prompt
end
