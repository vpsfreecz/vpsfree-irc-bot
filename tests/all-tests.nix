{
  pkgs ? <nixpkgs>,
  system ? builtins.currentSystem,
  configuration ? null,
  testConfig ? { },
  suiteArgs ? { },
  testFramework,
}:
let
  vpsadminPath = suiteArgs.vpsadminPath or (throw "suiteArgs.vpsadminPath is required");
  botPackage = suiteArgs.botPackage or (throw "suiteArgs.botPackage is required");
  suiteArgs' = suiteArgs // {
    inherit
      vpsadminPath
      botPackage
      ;
  };

  nixpkgs = import pkgs { inherit system; };
  lib = nixpkgs.lib;
  testLib = testFramework.makeTestLib {
    inherit
      pkgs
      system
      lib
      configuration
      testConfig
      ;
    suiteArgs = suiteArgs';
    suitePath = ./suite;
  };
in
testLib.makeTests [
  "irc-basic"
  "vpsadmin-events"
]
