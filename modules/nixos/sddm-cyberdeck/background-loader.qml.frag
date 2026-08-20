
        // Animated cyberdeck backdrop, spliced in by the sddm-astronaut
        // override in modules/nixos/mixins/hyprland.nix. Kept behind a Loader
        // so a QML error in it degrades to the plain preset wallpaper instead
        // of taking the greeter's login form down with it.
        //
        // z sits between the wallpaper (0) and the form (1) so the rain falls
        // over the artwork rather than behind it.
        Loader {
            id: cyberBackground

            anchors.fill: parent
            z: 0.5
            asynchronous: true
            source: "Components/CyberBackground.qml"
        }
