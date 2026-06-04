import ../make-test.nix (
  {
    pkgs,
    botPackage,
    vpsadminPath,
    ...
  }:
  let
    hostForwardName = "irc-vpsadmin";
    servicesAddress = "192.168.10.10";
    ircAddress = "192.168.10.20";
    seed = import (vpsadminPath + "/api/db/seeds/test.nix");
    adminUserId = seed.adminUser.id;
  in
  {
    name = "vpsadmin-events";

    description = ''
      Boot vpsAdmin services, ngIRCd and vpsfree-irc-bot, then verify that the
      bot connects to vpsAdmin and announces vpsAdmin events on IRC.
    '';

    tags = [
      "ci"
      "irc"
      "vpsadmin"
    ];

    machines = {
      services = {
        spin = "nixos";
        tags = [ "vpsadmin-services" ];
        networks = [
          { type = "user"; }
          { type = "socket"; }
        ];
        config = {
          imports = [
            (vpsadminPath + "/tests/configs/nixos/vpsadmin-services.nix")
          ];
          vpsadmin.test.socketPeers = {
            "irc.test" = ircAddress;
          };
          networking.firewall.allowedTCPPorts = [ 80 ];
        };
      };

      irc = import ./common.nix {
        inherit
          pkgs
          botPackage
          hostForwardName
          ;
        socketAddress = ircAddress;
        socketPeers = {
          ${servicesAddress} = [
            "api.vpsadmin.test"
            "webui.vpsadmin.test"
          ];
        };
        settings = {
          api_url = "http://api.vpsadmin.test";
          web_event_log = {
            channels = [ "#vpsfree" ];
          };
          outage_reports = {
            channels = [ "#vpsfree" ];
          };
          security_advisories = {
            channels = [ "#vpsfree" ];
          };
        };
        environment = {
          VPSFREE_IRC_BOT_WEB_EVENT_LOG_INTERVAL = "2";
          VPSFREE_IRC_BOT_OUTAGE_CHECK_INTERVAL = "2";
          VPSFREE_IRC_BOT_OUTAGE_REMIND_INTERVAL = "2";
          VPSFREE_IRC_BOT_SECURITY_ADVISORY_CHECK_INTERVAL = "2";
        };
      };
    };

    testScript = ''
      require 'securerandom'

      configure_examples do |config|
        config.default_order = :defined
      end

      CHANNEL = '#vpsfree'
      BOT_NICK = 'vpsfbot'
      WEBUI_BASE_URL = 'http://webui.vpsadmin.test'

      client = nil
      outage_id = nil
      security_advisory_id = nil

      def irc_port
        IrcBotHostfwdPorts.port('${hostForwardName}')
      end

      def unique_label(prefix)
        "#{prefix} #{SecureRandom.hex(4)}"
      end

      def connect_client
        IrcBotClient.connect(port: irc_port, nick: 'observer', channel: CHANNEL, timeout: 90)
      end

      def wait_for_outage_plugin_ready(irc_client)
        deadline = Time.now + 120

        loop do
          irc_client.command('!outage')
          line = irc_client.wait_for_privmsg(
            from: BOT_NICK,
            target: CHANNEL,
            pattern: /Status unknown|No outage reported|No relevant outage reported currently/,
            timeout: 15
          )

          return unless line.include?('Status unknown')

          raise OsVm::TimeoutError, 'Timed out waiting for outage plugin API setup' if Time.now >= deadline

          sleep 2
        end
      end

      def outage_url(id)
        "#{WEBUI_BASE_URL}/?page=outage&action=show&id=#{id}"
      end

      def security_advisory_url(id)
        "#{WEBUI_BASE_URL}/?page=security_advisory&action=show&id=#{id}"
      end

      def configure_vpsadmin_webui_base_url
        services.api_ruby(code: <<~RUBY)
          cfg = SysConfig.find_or_initialize_by(category: 'webui', name: 'base_url')
          cfg.data_type ||= 'String'
          cfg.min_user_level = 0 if cfg.min_user_level.nil?
          cfg.value = #{WEBUI_BASE_URL.inspect}
          cfg.save!
        RUBY
      end

      def create_news(message)
        services.api_ruby_json(code: <<~RUBY)
          message = #{message.inspect}
          NewsLog.create!(message: message, published_at: Time.now)
          puts JSON.dump(message: message)
        RUBY
      end

      def create_announced_outage(summary)
        services.api_ruby_json(code: <<~RUBY)
          summary = #{summary.inspect}
          lang = Language.find_by!(code: 'en')
          admin = User.find(${toString adminUserId})
          outage = Outage.create!(
            begins_at: Time.now - 60,
            duration: 30,
            state: :announced,
            outage_type: :planned_outage,
            impact_type: :network
          )
          OutageTranslation.create!(
            outage: outage,
            language: lang,
            summary: summary,
            description: 'Created by the IRC bot integration test'
          )
          OutageEntity.create!(outage: outage, name: 'Cluster')
          OutageHandler.create!(outage: outage, user: admin)
          puts JSON.dump(id: outage.id, summary: summary)
        RUBY
      end

      def create_outage_update(id, summary)
        services.api_ruby_json(code: <<~RUBY)
          id = #{id}
          summary = #{summary.inspect}
          lang = Language.find_by!(code: 'en')
          admin = User.find(${toString adminUserId})
          outage = Outage.find(id)
          update = OutageUpdate.create!(
            outage: outage,
            reported_by: admin,
            duration: 45,
            impact_type: :performance,
            created_at: Time.now,
            updated_at: Time.now
          )
          OutageTranslation.create!(
            outage_update: update,
            language: lang,
            summary: summary,
            description: 'Updated by the IRC bot integration test'
          )
          puts JSON.dump(id: update.id, summary: summary)
        RUBY
      end

      def create_security_advisory(summary)
        services.api_ruby_json(code: <<~RUBY)
          Dir[File.join(ENV.fetch('API_DIR'), 'models', 'security_advisory*.rb')]
            .sort
            .each { |path| require path }
          summary = #{summary.inspect}
          cve = "CVE-2026-#{rand(1000..9999)}"
          name = "IRC Bot Kernel Bug #{rand(1000..9999)}"
          lang = Language.find_by!(code: 'en')
          admin = User.find(${toString adminUserId})
          advisory = SecurityAdvisory.create!(
            state: :draft,
            name: name,
            created_by: admin
          )
          advisory.update_cves!(cve)
          advisory.update_translations!(
            lang => {
              summary: summary,
              description: 'Created by the IRC bot integration test',
              response: 'All affected nodes were mitigated'
            }
          )
          SecurityAdvisory.advisory_nodes.each do |node|
            SecurityAdvisoryNodeStatus.create!(
              security_advisory: advisory,
              node: node,
              state: :mitigated,
              vulnerable_until: Time.now - 3600,
              mitigated_since: Time.now - 1800
            )
          end
          advisory.publish!(published_by: admin)
          puts JSON.dump(
            id: advisory.id,
            summary: summary,
            cves: advisory.security_advisory_cves.order(:cve_id).map { |cve|
              {
                id: cve.id,
                cve_id: cve.cve_id,
                url: cve.url
              }
            },
            name: name,
            affected_node_count: advisory.affected_node_count
          )
        RUBY
      end

      def create_security_advisory_update(id, summary)
        services.api_ruby_json(code: <<~RUBY)
          Dir[File.join(ENV.fetch('API_DIR'), 'models', 'security_advisory*.rb')]
            .sort
            .each { |path| require path }
          id = #{id}
          summary = #{summary.inspect}
          lang = Language.find_by!(code: 'en')
          admin = User.find(${toString adminUserId})
          advisory = SecurityAdvisory.find(id)
          update = advisory.security_advisory_updates.create!(
            reported_by: admin,
            created_at: Time.now,
            updated_at: Time.now
          )
          update.security_advisory_translations.create!(
            language: lang,
            summary: summary,
            message: 'Updated by the IRC bot integration test'
          )
          puts JSON.dump(id: update.id, summary: summary)
        RUBY
      end

      before(:suite) do
        services.start
        services.wait_for_vpsadmin_api(timeout: 600)
        configure_vpsadmin_webui_base_url

        irc.start
        irc.wait_until_succeeds("ip -4 addr show dev eth0 | grep -q '10\\.0\\.2\\.'")
        irc.wait_until_succeeds("ip -4 addr show dev eth1 | grep -q '${ircAddress}'")
        irc.wait_until_succeeds(
          "curl --silent --fail-with-body http://api.vpsadmin.test/ | grep -q 'API description'",
          timeout: 120
        )
        irc.wait_for_service('ngircd')
        irc.wait_for_service('vpsfree-irc-bot')
        irc.succeeds('systemctl restart vpsfree-irc-bot')
        irc.wait_for_service('vpsfree-irc-bot')

        client = connect_client
        client.wait_for_names_include(BOT_NICK)
        client.command('!ping')
        client.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: 'pong')

        # Let polling plugins initialize their `since` timestamps after API setup.
        sleep 4
        wait_for_outage_plugin_ready(client)
      end

      after(:suite) do
        client&.close
      end

      describe 'vpsAdmin API commands' do
        it 'reports public node status' do
          client.command('!status')
          client.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, pattern: /\d+ nodes online/)
        end
      end

      describe 'vpsAdmin event announcements' do
        it 'announces news log entries' do
          message = unique_label('IRC Bot News Event')
          create_news(message)

          client.wait_for_privmsg(
            from: BOT_NICK,
            target: CHANNEL,
            text: "News from vpsAdmin: #{message}",
            timeout: 90
          )
        end

        it 'announces new outages and answers the outage command' do
          summary = unique_label('IRC Bot Planned Outage')
          outage = create_announced_outage(summary)
          outage_id = outage.fetch('id')

          client.wait_for_privmsg(
            from: BOT_NICK,
            target: CHANNEL,
            text: "New planned outage ##{outage_id}",
            timeout: 90
          )
          client.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: "Reason: #{summary}")
          client.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: outage_url(outage_id))

          client.command('!outage')
          client.wait_for_privmsg(
            from: BOT_NICK,
            target: CHANNEL,
            text: "Planned outage ##{outage_id}"
          )
          client.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: "Reason: #{summary}")
          client.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: outage_url(outage_id))
        end

        it 'announces outage updates' do
          summary = unique_label('IRC Bot Outage Update')
          create_outage_update(outage_id, summary)

          client.wait_for_privmsg(
            from: BOT_NICK,
            target: CHANNEL,
            text: "Update of planned outage ##{outage_id}",
            timeout: 90
          )
          client.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: 'Duration: 45 minutes')
          client.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: "Summary: #{summary}")
          client.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: outage_url(outage_id))
        end

        it 'announces new security advisories' do
          summary = unique_label('IRC Bot Security Advisory')
          advisory = create_security_advisory(summary)
          security_advisory_id = advisory.fetch('id')
          cve_ids = advisory.fetch('cves').map { |cve| cve.fetch('cve_id') }.join(', ')

          client.wait_for_privmsg(
            from: BOT_NICK,
            target: CHANNEL,
            text: "New security advisory ##{security_advisory_id}",
            timeout: 90
          )
          client.wait_for_privmsg(
            from: BOT_NICK,
            target: CHANNEL,
            text: "CVE: #{cve_ids} (#{advisory.fetch('name')})"
          )
          client.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: "Summary: #{summary}")
          client.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: security_advisory_url(security_advisory_id))
        end

        it 'announces security advisory updates' do
          summary = unique_label('IRC Bot Security Advisory Update')
          create_security_advisory_update(security_advisory_id, summary)

          client.wait_for_privmsg(
            from: BOT_NICK,
            target: CHANNEL,
            text: "Update of security advisory ##{security_advisory_id}",
            timeout: 90
          )
          client.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: "Summary: #{summary}")
          client.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: security_advisory_url(security_advisory_id))
        end
      end
    '';
  }
)
