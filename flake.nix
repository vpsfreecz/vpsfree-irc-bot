{
  description = "vpsFree.cz IRC bot";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };

          ruby = pkgs.ruby_3_3;
        in
        {
          default = pkgs.mkShell {
            name = "vpsfree-irc-bot";

            packages = [
              pkgs.bundix
              pkgs.git
              pkgs.gnumake
              pkgs.jq
              pkgs.libxml2
              pkgs.libxslt
              pkgs.nixfmt
              pkgs.openssl
              pkgs.pkg-config
              ruby
              pkgs.zlib
            ];

            shellHook = ''
              export GEM_HOME="$PWD/.gems"
              mkdir -p "$GEM_HOME"
              export GEM_PATH="$GEM_HOME:$PWD/lib"
              export PATH="$GEM_HOME/bin:$PATH"

              if [ -n "''${PS1:-}" ]; then
                case "$PS1" in
                  "(vpsfree-irc-bot) "*) ;;
                  *) export PS1="(vpsfree-irc-bot) $PS1" ;;
                esac
              fi

              BUNDLE="$GEM_HOME/bin/bundle"
              [ ! -x "$BUNDLE" ] && ${ruby}/bin/gem install --no-document bundler

              export BUNDLE_PATH="$GEM_HOME"
              export BUNDLE_GEMFILE="$PWD/Gemfile"

              "$BUNDLE" config set build.nokogiri --use-system-libraries

              # prism's native extension can fail to see its generated headers
              # when built through Nix's purity wrapper.
              NIX_ENFORCE_PURITY=0 "$BUNDLE" install

              export RUBYOPT=-rbundler/setup
            '';
          };
        }
      );
    };
}
