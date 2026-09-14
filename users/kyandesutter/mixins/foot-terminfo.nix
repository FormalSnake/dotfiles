{ lib, ... }:
{
  # SSH sessions from foot on the Linux hosts arrive with TERM=foot, which
  # macOS's ncurses has no entry for, so full-screen apps fail with "unknown
  # terminal type". Compile the captured entry (./foot.terminfo, from
  # `infocmp -x foot` on a Linux host) into ~/.terminfo with the system tic so
  # the output matches Apple's ncurses readers. ~/.terminfo is searched
  # unconditionally, no env var needed.
  home.activation.footTerminfo = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -x /usr/bin/tic ]; then
      run /usr/bin/tic -x -o "$HOME/.terminfo" ${./foot.terminfo} || true
    fi
  '';
}
