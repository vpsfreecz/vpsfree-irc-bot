testFn:
{
  vpsadminosPath,
  vpsadminPath,
  botPackage,
  ...
}@args:
let
  upstream = import (vpsadminosPath + "/tests/make-test.nix") testFn;
  mergedExtraArgs = {
    vpsadminos = vpsadminosPath;
    vpsadmin = vpsadminPath;
    inherit botPackage;
  }
  // (args.extraArgs or { });
  argsWithExtra = args // {
    extraArgs = mergedExtraArgs;
  };
in
upstream argsWithExtra
