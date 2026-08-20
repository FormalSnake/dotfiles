
        // Animated cyberdeck backdrop, spliced in by the sddm-astronaut
        // override in modules/nixos/mixins/hyprland.nix. Kept behind a Loader
        // so a QML error in it degrades to a black background instead of
        // taking the greeter's login form down with it.
        Loader {
            id: cyberBackground

            anchors.fill: parent
            z: 0
            asynchronous: true
            source: "Components/CyberBackground.qml"
        }
