let
  pkgs = import <nixpkgs> {};
  stdenv = pkgs.stdenv;

in stdenv.mkDerivation rec {
  name = "vpsfree-irc-bot";

  buildInputs = with pkgs;[
    ruby
    git
    libxml2
    libxslt
    zlib
    openssl
    pkgconfig
  ];

  shellHook = ''
    export GEM_HOME="$PWD/.gems"
    mkdir -p "$GEM_HOME"
    export GEM_PATH="$GEM_HOME:$PWD/lib"
    export PATH="$GEM_HOME/bin:$PATH"

    BUNDLE="$GEM_HOME/bin/bundle"

    [ ! -x "$BUNDLE" ] && ${pkgs.ruby}/bin/gem install bundler

    export BUNDLE_PATH="$GEM_HOME"
    export BUNDLE_GEMFILE="$PWD/Gemfile"

    $BUNDLE config build.nokogiri --use-system-libraries
    echo run `bundle install` if needed
  '';
}
