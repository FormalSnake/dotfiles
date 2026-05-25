{
  programs.git = {
    enable = true;
    lfs.enable = true;

    settings = {
      user = {
        name = "FormalSnake";
        email = "kyaniserni@gmail.com";
      };
      core.precomposeUnicode = true;
      init.defaultBranch = "main";
      http.postBuffer = 157286400;
      pull.rebase = false;
    };
  };
}
