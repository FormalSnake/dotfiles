# Every key that logs in as the user and, through a forwarded agent, authenticates sudo.
KEYS = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIcVJF2yg72gRq6NceAnchCIgIWfC2Xx2Va2vcq1GVOm personal_mac",
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGxYo1mVlFzYfDSiHH4nWXYs+ZFz29vYlkRkWxQKxMFv kyandesutter@g815",
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOYmDpRg/oAI5/NSJbEzOZHJqEg8YoTT2Nrv5fwLLXWi kyandesutter@e1504g",
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIzOtD8dGRhHAsYHY8Mb8/sI9Oaf1k8/0iw/GGXaooFP kyandesutter@desktop-vjmk52d",
]

AUTHORIZED_KEYS = "\n".join(KEYS) + "\n"
