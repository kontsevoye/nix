{
  config,
  pkgs,
  lib,
  ...
}:

let
  gitIdentity = pkgs.writeShellScriptBin "git-identity" (builtins.readFile ./git-identity.sh);
  php = pkgs.php84.buildEnv {
    extensions =
      { all, enabled }:
      with all;
      enabled
      ++ [
        redis
        amqp
        xdebug
        pcov
      ];
  };
in
{
  home.stateVersion = "25.11";

  home.packages =
    with pkgs;
    [
      nerd-fonts.hack
      android-tools
      ansible
      bat
      bun
      curl
      cloudflared
      devenv
      fcgi
      ffmpeg
      fzf
      gh
      gitIdentity
      go
      htop
      imagemagick
      jq
      lazydocker
      nodejs_20
      php
      php.packages.composer
      (python312.withPackages (
        p: with p; [
          pip
          pycryptodome
          setuptools
        ]
      ))
      starship
      streamlink
      symfony-cli
      tmux
      wasmer
      wget
      yt-dlp
      yq
      nixfmt-rfc-style
      pigz
      e2fsprogs
      mtr
      cachix
      skopeo
      umoci
      bore-cli
      attic-client
      codex
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      pinentry
      yandex-disk
      wasmtime
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [ pinentry_mac ];

  home.file = {
    ".gnupg/gpg-agent.conf".text = (
      if (pkgs.stdenv.isDarwin) then
        ''
          pinentry-program ${pkgs.pinentry_mac}/bin/pinentry-mac
        ''
      else
        ''
          pinentry-program ${pkgs.pinentry}/bin/pinentry
        ''
    );
  };

  home.sessionVariables = {
    GPG_TTY = "$(tty)";
  };

  programs.home-manager.enable = true;
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    silent = true;
  };

  programs.gpg = {
    enable = true;
    package = pkgs.gnupg24;
    publicKeys = [
      {
        source = ./instane_at_gmail_dot_com.rsa.txt;
        trust = 5;
      }
      {
        source = ./instane_at_gmail_dot_com.ed25519.txt;
        trust = 5;
      }
      {
        source = ./e_dot_kontsevoy_at_propellerads_dot_net.rsa.txt;
        trust = 5;
      }
    ];
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
    signing = {
      signer = "${pkgs.gnupg24}/bin/gpg2";
      # required by signing module, but would be overwritten in extraConfig by git identity
      key = "04560FBB83458AA8";
      signByDefault = true;
    };
    extraConfig = {
      # extremely important, otherwise git will attempt to guess a default user identity. see `man git-config` for more details
      user.useConfigOnly = true;
      user.work.name = "Evgeny Kontsevoy";
      user.work.email = "e.kontsevoy@propellerads.net";
      user.work.signingKey = "E90527496D26FA0F";
      user.personal.name = "Evgenii Kontsevoi";
      user.personal.email = "instane@gmail.com";
      user.personal.signingKey = "04560FBB83458AA8";
      user.personal_ed.name = "Evgenii Kontsevoi";
      user.personal_ed.email = "instane@gmail.com";
      user.personal_ed.signingKey = "1F2A8E0294C59B8A";
    };
    aliases = {
      identity = "! git-identity";
      id = "! git-identity";
    };
    ignores = [
      ".DS_Store"
      ".idea"
    ];
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    plugins = with pkgs.vimPlugins; [
      vim-nix
      vim-monokai-pro
      nvim-lastplace
    ];
    extraConfig = ''
      set number
      colorscheme monokai_pro
    '';
    extraLuaConfig = ''
      require'nvim-lastplace'.setup{}
    '';
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    # compinit required during antidote plugin load
    # so it is loading a little bit earlier and original completionInit is overwritten with empty string
    initContent =
      let
        initExtraBeforeCompInit = lib.mkOrder 500 ''
          # do compinit only once a day
          # (reduce zsh load time from ~0.8s to ~0.1s)
          # todo generate it while building home-manager
          autoload -Uz compinit
          for dump in ~/.zcompdump(N.mh+24); do
            compinit
          done
          compinit -C
        '';
        initExtra = lib.mkOrder 1000 ''
          # Symfony completions
          compdef _symfony_complete symfony
          compdef _symfony_complete composer
        '';
      in
      lib.mkMerge [
        initExtraBeforeCompInit
        initExtra
      ];
    completionInit = "";
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    antidote.enable = true;
    antidote.plugins = [
      # Bundle Fish-like auto suggestions just like you would with antigen.
      "zsh-users/zsh-autosuggestions"
      # Bundle extra zsh completions too.
      "zsh-users/zsh-completions"
      "agkozak/zsh-z"
      # Symfony completions
      "voronkovich/symfony-complete.plugin.zsh path:symfony-complete.plugin.zsh"
      # Oh-my-zsh partial plugins
      "ohmyzsh/ohmyzsh path:lib/history.zsh"
      "ohmyzsh/ohmyzsh path:lib/git.zsh"
      "ohmyzsh/ohmyzsh path:lib/clipboard.zsh"
      "ohmyzsh/ohmyzsh path:lib/completion.zsh"
      "ohmyzsh/ohmyzsh path:lib/directories.zsh"
      "ohmyzsh/ohmyzsh path:plugins/git"
      "ohmyzsh/ohmyzsh path:plugins/fzf"
      "ohmyzsh/ohmyzsh path:plugins/docker"
      "ohmyzsh/ohmyzsh path:plugins/gh"
      "ohmyzsh/ohmyzsh path:plugins/brew"
      "ohmyzsh/ohmyzsh path:plugins/bun"
      "ohmyzsh/ohmyzsh path:plugins/starship"
    ];
    localVariables = {
      ZSH_CACHE_DIR = [ "$HOME/.zsh_cache" ];
    };
    envExtra = ''
      # Homebrew envs
      if [[ "$OSTYPE" == "darwin"* && -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      fi

      # Orbstack envs
      if [[ "$OSTYPE" == "darwin"* && -x "$HOME/.orbstack/shell/init.zsh" ]]; then
        source ~/.orbstack/shell/init.zsh 2>/dev/null || :
      fi

      # Custom path entries
      path=("$HOME/.composer/vendor/bin" $path)
      path=("$HOME/go/bin" $path)
      path=("$HOME/.local/bin" $path)
      if [[ "$OSTYPE" == "darwin"* && -x "$HOME/Library/Application Support/JetBrains/Toolbox/scripts" ]]; then
        path=("$HOME/Library/Application Support/JetBrains/Toolbox/scripts" $path)
      fi
    '';
  };
}
