function claude --wraps="claude"
    if not set -q CLAUDE_CONFIG_DIR
        set -l id
        set -l argc (count $argv)
        set -l i 0
        for arg in $argv
            set i (math $i + 1)
            switch $arg
                case --resume -r
                    if test $i -lt $argc
                        set id $argv[(math $i + 1)]
                    end
                case '--resume=*'
                    set id (string replace -- '--resume=' "" $arg)
            end
        end
        if test -n "$id"
            set -l pulse "$HOME/.claude-pulse"
            set -l owned $pulse/projects/*/$id.jsonl
            if test (count $owned) -gt 0
                CLAUDE_CONFIG_DIR=$pulse command claude $argv
                return
            end
        end
    end
    command claude $argv
end
