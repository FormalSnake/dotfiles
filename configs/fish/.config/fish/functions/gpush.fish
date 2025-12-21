function gpush --description 'Git add, commit with AI message, and push'
    git add .
    set commit_message (lumen draft)
    if test -z "$commit_message"
        echo "Lumen draft is empty"
        read -P "Enter commit message: " commit_message
    end
    git commit -avm "$commit_message"

    if test -n "$argv[1]"
        set branch_name $argv[1]
    else
        set branch_name main
    end
    git push origin $branch_name
end