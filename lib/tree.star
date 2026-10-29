def tree(roots, dest = "/", perms = {}, skip = []):
    """Every file under `roots` at the same path under `dest`. A later root wins."""
    files = {}
    for root in roots:
        for src in glob(root + "**/*"):
            rel = src.removeprefix(root)
            if any([rel == s or rel.startswith(s + "/") for s in skip]):
                continue
            path = dest + rel
            files[rel] = file(path, src = src, perms = perms.get(path))
    return list(files.values())

def merge(*dicts):
    out = {}
    for d in dicts:
        out.update(d)
    return out
