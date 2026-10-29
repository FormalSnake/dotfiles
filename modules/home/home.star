load("//lib/tree.star", "tree")
load("//modules/home/apps.star", "CLAUDE_PULSE", "FLATPAKS", "NVIM", "TOOLS")
load("//modules/home/discord.star", "DISCORD")
load("//modules/home/kde.star", "KDE")
load("//modules/home/services.star", "SERVICES")
load("//modules/t3code/t3code.star", "t3code")

def home(host):
    """The Linux home: home/ with hosts/<host>/home/ over it, and the user's apps and services."""
    return (
        tree(["home/", "hosts/%s/home/" % host], dest = "~/") +
        SERVICES + KDE + FLATPAKS + DISCORD + CLAUDE_PULSE + t3code(host) + TOOLS + NVIM
    )
