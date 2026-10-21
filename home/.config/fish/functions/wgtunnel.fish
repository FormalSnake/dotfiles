function wgtunnel --description="WireGuard-over-wstunnel client (endpoint + path prefix from /etc/fspec/secrets)"
    if not set -q WSTUNNEL_ENDPOINT; or not set -q WSTUNNEL_PATH_PREFIX
        echo "WSTUNNEL_ENDPOINT / WSTUNNEL_PATH_PREFIX not set (fspec secret missing?)" >&2
        return 1
    end
    wstunnel client \
        -L 'udp://51820:localhost:51820?timeout_sec=0' \
        --http-upgrade-path-prefix $WSTUNNEL_PATH_PREFIX \
        $WSTUNNEL_ENDPOINT $argv
end
