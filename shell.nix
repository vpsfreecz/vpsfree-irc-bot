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
    export NOKOGIRI_USE_SYSTEM_LIBRARIES=1
    bundle install
    export RUBYOPT=-rbundler/setup
  '';
}
