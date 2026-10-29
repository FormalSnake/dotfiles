function fish_prompt --description="One-line prompt: [host] dir branch* →"
    set -l last_status $status
    set -l normal (set_color normal)

    set -l dir (basename -- $PWD)
    test "$PWD" = "$HOME"; and set dir "~"
    test "$PWD" = /; and set dir /

    # One `git status --porcelain=v2 --branch` feeds branch, dirty and
    # ahead/behind (a git call per field makes the prompt lag).
    set -l branch ""
    set -l dirty ""
    set -l ab_txt ""
    set -l git_lines (command git status --porcelain=v2 --branch 2>/dev/null)
    and set branch (string replace -f '# branch.head ' "" -- $git_lines)
    if test -n "$branch"
        if test "$branch" = "(detached)"
            set branch (string sub -l7 -- (string replace -f '# branch.oid ' "" -- $git_lines))
        end
        string match -rq '^[12u?] ' -- $git_lines; and set dirty "*"

        set -l ab (string replace -f '# branch.ab ' "" -- $git_lines)
        if test -n "$ab"
            set -l p (string split " " -- $ab)
            set -l ahead (string sub -s2 -- $p[1])
            set -l behind (string sub -s2 -- $p[2])
            test $ahead != 0; and set ab_txt "$ab_txt⇡"
            test $behind != 0; and set ab_txt "$ab_txt⇣"
        end
    end

    if set -q SSH_CONNECTION; or set -q SSH_TTY; or set -q SSH_CLIENT
        set -l host (string lower (string replace -r '\..*$' "" -- $hostname))
        string match -q 'macbook*' -- $host; and set host macbook
        echo -n (set_color brblack)$host" "$normal
    end

    echo -n (set_color blue)$dir$normal
    if test -n "$branch"
        echo -n " "(set_color yellow)$branch$dirty$normal
        test -n "$ab_txt"; and echo -n " "(set_color cyan)$ab_txt$normal
    end

    if test $last_status -eq 0
        echo -n " "(set_color green)"→"$normal" "
    else
        echo -n " "(set_color red)"→"$normal" "
    end
end
