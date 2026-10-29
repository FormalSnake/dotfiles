# Kyan's hosts. README.md maps the repo.

load("//hosts/e1504g/host.star", "e1504g")
load("//hosts/fstestmac/host.star", "fstestmac")
load("//hosts/fstestvm/host.star", "fstestvm")
load("//hosts/g815/host.star", "g815")
load("//hosts/macbook/host.star", "macbook")

hosts = [e1504g, g815, macbook, fstestmac] + fstestvm
