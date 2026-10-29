# The host this machine is, for fspec; the macbook's OS calls itself MacBook-Pro-2.
def fspec(host):
    return file("/etc/fspec/host", content = host.name + "\n")
