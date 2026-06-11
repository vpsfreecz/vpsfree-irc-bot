testFn:
{
  testFramework,
  vpsadminPath,
  botPackage,
  ...
}@args:
let
  upstream = testFramework.makeTest testFn;
  mergedExtraArgs = {
    vpsadminos = testFramework.sourcePath;
    vpsadmin = vpsadminPath;
    inherit botPackage;
  }
  // (args.extraArgs or { });
  argsWithExtra = args // {
    extraArgs = mergedExtraArgs;
  };
in
upstream argsWithExtra
