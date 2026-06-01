{
  pkgs,
  botPackage,
  hostForwardName,
  settings ? { },
  environment ? { },
  extraConfig ? { },
  socketAddress ? null,
  socketPeers ? { },
}:
let
  baseSettings = {
    server = {
      label = "irc.test";
      host = "127.0.0.1";
    };
    channels = [ "#vpsfree" ];
    nick = "vpsfbot";
    api_url = null;
    archive_url = "http://archive.test";
    archive_dst = "/var/lib/vpsfree-irc-bot/archive";
    state_dir = "/var/lib/vpsfree-irc-bot/state";
    easter_eggs = false;
  };

  configFile = pkgs.writeText "vpsfree-irc-bot-config.json" (
    builtins.toJSON (baseSettings // settings)
  );

  socketConfig =
    if socketAddress == null then
      { }
    else
      {
        networking.interfaces.eth1.useDHCP = false;
        networking.interfaces.eth1.ipv4.addresses = [
          {
            address = socketAddress;
            prefixLength = 24;
          }
        ];
        networking.hosts = socketPeers;
      };
in
{
  spin = "nixos";
  memory = 1536;
  networks = [
    {
      type = "user";
      opts = {
        hostForward = "tcp::${hostForwardName}-:6667";
        network = "10.0.2.0/24";
        host = "10.0.2.2";
        dns = "10.0.2.3";
      };
    }
  ]
  ++ pkgs.lib.optional (socketAddress != null) { type = "socket"; };
  config =
    {
      pkgs,
      lib,
      ...
    }:
    lib.mkMerge [
      {
        networking.firewall.allowedTCPPorts = [ 6667 ];

        environment.systemPackages = [ pkgs.curl ];

        services.ngircd = {
          enable = true;
          config = ''
            [Global]
              Name = irc.test
              Info = vpsfree-irc-bot integration test IRC server
              Ports = 6667
              Listen = 0.0.0.0

            [Options]
              DNS = no
              Ident = no
              PAM = no

            [Channel]
              Name = #vpsfree
              Topic = Integration test channel
          '';
        };

        users.groups.vpsfbot = { };
        users.users.vpsfbot = {
          isSystemUser = true;
          group = "vpsfbot";
          home = "/var/lib/vpsfree-irc-bot";
          createHome = true;
        };

        systemd.tmpfiles.rules = [
          "d /var/lib/vpsfree-irc-bot 0755 vpsfbot vpsfbot -"
          "d /var/lib/vpsfree-irc-bot/archive 0755 vpsfbot vpsfbot -"
          "d /var/lib/vpsfree-irc-bot/state 0755 vpsfbot vpsfbot -"
        ];

        systemd.services.vpsfree-irc-bot = {
          after = [
            "network-online.target"
            "ngircd.service"
          ];
          wants = [
            "network-online.target"
            "ngircd.service"
          ];
          wantedBy = [ "multi-user.target" ];
          environment = {
            LANG = "C.UTF-8";
            RACK_ENV = "production";
            VPSFREE_IRC_BOT_EASTER_EGGS = "0";
          }
          // environment;
          serviceConfig = {
            Type = "simple";
            User = "vpsfbot";
            Group = "vpsfbot";
            WorkingDirectory = "/var/lib/vpsfree-irc-bot";
            ExecStart = "${botPackage}/bin/bundle exec ${botPackage}/vpsfree-irc-bot/bin/vpsfree-irc-bot --config ${configFile}";
            Restart = "on-failure";
            RestartSec = 1;
          };
        };
      }
      socketConfig
      extraConfig
    ];
}
