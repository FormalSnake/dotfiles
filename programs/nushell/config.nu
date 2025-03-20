
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

source ~/.zoxide.nu


      alias cd = z
