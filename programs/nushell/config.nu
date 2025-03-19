
      let carapace_completer = {|spans|
      carapace $spans.0 nushell ...$spans | from json
      }
      $env.config = {
       show_banner: false,
       completions: {
       case_sensitive: false # case-sensitive completions
       quick: true    # set to false to prevent auto-selecting completions
       partial: true    # set to false to prevent partial filling of the prompt
       algorithm: "fuzzy"    # prefix or fuzzy
       external: {
       # set to false to prevent nushell looking into $env.PATH to find more suggestions
           enable: true
       # set to lower can improve completion performance at the cost of omitting some options
           max_results: 100
           completer: $carapace_completer # check 'carapace_completer'
         }
       }
      }

      alias vim = nvim
      alias add = git add
      alias commit = git commit
      alias push = git push

      def commitai [] {
        git commit -avm (lumen draft)
      }

      def nah [] {
        git reset --hard
        git clean -df
      }

      def nixrb [] {
        clear
        darwin-rebuild switch --flake .
      }

      def nixrbgc [] {
        clear
        darwin-rebuild switch --flake .
        sudo nix-collect-garbage -d
      }

      def wallpaper [] {
        matugen -c ~/.config/matugen/config.toml --verbose --contrast 0.2 image
      }

      def gpush [] {
        git add .
        let commit_message = (lumen draft)
        if ($commit_message | is-empty) {
          print "Lumen draft is empty"
          let commit_message = (input "Enter commit message: ")
        }
        git commit -avm $commit_message
        git push origin main
      }

      $env.PROMPT_COMMAND_RIGHT = {||
    # create a right prompt in magenta with green separators and am/pm underlined
    let time_segment = ([
        (ansi reset)
        (ansi magenta)
        (date now | format date '%X') # try to respect user's locale
    ] | str join | str replace --regex --all "([/:])" $"(ansi green)${1}(ansi magenta)" |
        str replace --regex --all "([AP]M)" $"(ansi magenta_underline)${1}")

    let last_exit_code = if ($env.LAST_EXIT_CODE != 0) {([
        (ansi rb)
        ($env.LAST_EXIT_CODE)
    ] | str join)
    } else { "" }

    ([$last_exit_code, (char space), $time_segment] | str join)
}

source ~/.zoxide.nu


      alias cd = z
