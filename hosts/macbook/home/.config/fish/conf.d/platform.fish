# launchd agents do not read these; each one sets its own.
set -gx ANDROID_HOME ~/Library/Android/sdk
set -gx JAVA_HOME /Library/Java/JavaVirtualMachines/zulu-21.jdk/Contents/Home
fish_add_path --append $ANDROID_HOME/platform-tools $ANDROID_HOME/emulator $ANDROID_HOME/cmdline-tools/latest/bin

# SSH commands are noninteractive, so Homebrew's paths are static here instead of `brew shellenv`
# per command. config.fish moves the user and store tools back in front.
fish_add_path --path --append /opt/homebrew/bin /opt/homebrew/sbin

status is-interactive; or exit

/opt/homebrew/bin/brew shellenv | source
test -f ~/.orbstack/shell/init2.fish; and source ~/.orbstack/shell/init2.fish

if test (defaults read -g AppleInterfaceStyle 2>/dev/null) = Dark
    fish_config theme choose "Flexoki Dark"
else
    fish_config theme choose "Flexoki Light"
end
