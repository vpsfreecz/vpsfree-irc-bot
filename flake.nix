{
  description = "vpsFree.cz IRC bot";

  inputs = {
    vpsadmin.url = "github:vpsfreecz/vpsadmin";
    vpsadminos.follows = "vpsadmin/vpsadminos";
    nixpkgs.follows = "vpsadminos/nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      vpsadmin,
      vpsadminos,
      ...
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      testSystems = [ "x86_64-linux" ];

      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      forTestSystems = nixpkgs.lib.genAttrs testSystems;
      pkgsFor = system: import nixpkgs { inherit system; };

      mkPackage =
        system:
        let
          pkgs = pkgsFor system;
          ruby = pkgs.ruby_3_3;
          src = pkgs.lib.cleanSourceWith {
            src = ./.;
            filter =
              path: type:
              let
                root = toString ./.;
                relPath = pkgs.lib.removePrefix "${root}/" (toString path);
              in
              pkgs.lib.cleanSourceFilter path type
              && relPath != "result"
              && relPath != ".bundle"
              && relPath != ".gems";
          };
        in
        pkgs.bundlerEnv {
          name = "vpsfree-irc-bot";
          inherit ruby;
          gemdir = src;
          gemConfig.nokogiri = attrs: {
            buildInputs = [
              pkgs.libxml2
              pkgs.libxslt
            ];
          };
          postBuild = ''
            ln -s ${src} $out/vpsfree-irc-bot
          '';
        };

      suiteArgsFor =
        system:
        {
          vpsadminosPath = vpsadminos.outPath;
          vpsadminPath = vpsadmin.outPath;
          botPackage = self.packages.${system}.vpsfree-irc-bot;
        };
    in
    {
      packages = forAllSystems (system: {
        vpsfree-irc-bot = mkPackage system;
        default = self.packages.${system}.vpsfree-irc-bot;
      });

      apps = forTestSystems (system: {
        test-runner = {
          type = "app";
          program = "${vpsadminos.packages.${system}.test-runner}/bin/test-runner";
        };
      });

      tests = forTestSystems (
        system:
        vpsadminos.lib.testFramework.mkTests {
          inherit system;
          pkgsPath = nixpkgs.outPath;
          testsRoot = ./tests;
          suiteArgs = suiteArgsFor system;
        }
      );

      testsMeta = forTestSystems (
        system:
        vpsadminos.lib.testFramework.mkTestsMeta {
          inherit system;
          pkgsPath = nixpkgs.outPath;
          testsRoot = ./tests;
          suiteArgs = suiteArgsFor system;
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;

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
