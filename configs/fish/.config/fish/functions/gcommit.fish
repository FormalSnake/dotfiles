function gcommit --description 'Git add and commit with AI message'
    git add .
    set commit_message (lumen draft)
    if test -z "$commit_message"
        echo "Lumen draft is empty"
        read -P "Enter commit message: " commit_message
    end
    git commit -avm "$commit_message"
end