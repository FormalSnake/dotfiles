# /etc/profile resets PATH, and bash runs it even for `ssh host 'bash -c ...'`, so store tools
# need re-adding here; fish and the session get them from environment.d.
case ":$PATH:" in
    *:/opt/fspec/current/bin:*) ;;
    *) PATH=/opt/fspec/current/bin:$PATH ;;
esac
