import ../make-test.nix (
  {
    pkgs,
    botPackage,
    ...
  }:
  let
    hostForwardName = "irc-github-webhook";
  in
  {
    name = "irc-github-webhook";
    description = ''
      Verify signed GitHub webhooks, channel filtering and channel logs with
      ngIRCd and the bot in one disposable VM.
    '';
    tags = [
      "ci"
      "irc"
      "light"
    ];

    machines.irc = import ./common.nix {
      inherit pkgs botPackage hostForwardName;
      settings = {
        channels = [
          "#vpsfree"
          "#vpsadminos"
        ];
        github_webhook = {
          host = "127.0.0.1";
          port = 8000;
          secret = "disposable-webhook-test-secret";
          channels = {
            "#vpsfree" = {
              repositories = [ "test/webhooks" ];
              ignored_users = [ "github-actions[bot]" ];
            };
            "#vpsadminos" = [ "test/webhooks" ];
          };
        };
      };
    };

    testScript = ''
      require 'openssl'

      CHANNELS = %w[#vpsfree #vpsadminos].freeze
      BOT_NICK = 'vpsfbot'
      SECRET = 'disposable-webhook-test-secret'
      REPOSITORY_URL = 'https://github.com/test/webhooks'
      clients = {}

      def user(login)
        { 'id' => 1, 'login' => login, 'html_url' => "https://github.com/#{login}" }
      end

      def repository
        {
          'id' => 1, 'name' => 'webhooks', 'full_name' => 'test/webhooks',
          'html_url' => REPOSITORY_URL, 'default_branch' => 'master', 'owner' => user('test')
        }
      end

      def commit(login, marker)
        {
          'id' => 'b' * 40, 'message' => marker, 'distinct' => true,
          'author' => { 'name' => login == 'human' ? 'Human' : 'Automation',
                        'email' => "#{login}@users.noreply.github.com", 'username' => login }
        }
      end

      def push_payload(marker, sender:, commits:, forced: false)
        {
          'sender' => user(sender), 'repository' => repository, 'ref' => 'refs/heads/master',
          'before' => 'a' * 40, 'after' => 'b' * 40, 'created' => false, 'deleted' => false,
          'forced' => forced, 'compare' => "#{REPOSITORY_URL}/compare/#{marker}", 'commits' => commits
        }
      end

      def post_webhook(type, payload, valid: true)
        body = JSON.generate(payload)
        signature = valid ? OpenSSL::HMAC.hexdigest('sha1', SECRET, body) : '0' * 40
        irc.succeeds("printf %s #{Shellwords.escape(body)} > /tmp/github-webhook.json")
        _, status = irc.succeeds(
          "curl --silent --show-error --output /tmp/github-webhook-response --write-out '%{http_code}' " \
          "--header #{Shellwords.escape("X-GitHub-Event: #{type}")} " \
          "--header #{Shellwords.escape("X-Hub-Signature: sha1=#{signature}")} " \
          "--header 'Content-Type: application/json' --data-binary @/tmp/github-webhook.json " \
          'http://127.0.0.1:8000/gh-webhook'
        )
        expect(status.strip).to eq(valid ? '200' : '400')
      end

      def channel_log(channel, format)
        directory = "/var/lib/vpsfree-irc-bot/archive/#{format}/irc.test/#{channel}"
        _, output = irc.succeeds(
          "find #{Shellwords.escape(directory)} -type f -name #{Shellwords.escape("*.#{format}")} -exec cat {} +"
        )
        output
      end

      before(:suite) do
        irc.start
        irc.wait_for_service('ngircd')
        irc.wait_for_service('vpsfree-irc-bot')
        irc.wait_until_succeeds('curl --silent --output /dev/null http://127.0.0.1:8000/')
        CHANNELS.each_with_index do |channel, index|
          clients[channel] = IrcBotClient.connect(
            port: IrcBotHostfwdPorts.port('${hostForwardName}'), nick: "observer#{index}", channel: channel
          )
          clients[channel].wait_for_names_include(BOT_NICK)
          clients[channel].command('!ping')
          clients[channel].wait_for_privmsg(from: BOT_NICK, target: channel, text: 'pong')
        end
      end

      after(:suite) do
        clients.each_value(&:close)
      end

      describe 'signed GitHub announcements' do
        it 'filters each channel independently and keeps IRC and archive output consistent' do
          post_webhook('push', push_payload(
            'mixed-range', sender: 'github-actions[bot]',
            commits: [commit('github-actions[bot]', 'mixed-ignored'), commit('human', 'mixed-human')]
          ))
          post_webhook('push', push_payload(
            'all-ignored-range', sender: 'human', commits: [commit('github-actions[bot]', 'all-ignored-subject')]
          ))
          post_webhook('push', push_payload(
            'force-range', sender: 'human', forced: true,
            commits: [commit('github-actions[bot]', 'force-ignored'), commit('human', 'force-human')]
          ))
          post_webhook('issues', {
            'sender' => user('github-actions[bot]'), 'repository' => repository, 'action' => 'opened',
            'issue' => { 'id' => 91, 'number' => 91, 'title' => 'Ignored issue', 'state' => 'open',
                         'html_url' => "#{REPOSITORY_URL}/issues/ignored-issue", 'user' => user('human') }
          })
          post_webhook('push', push_payload(
            'invalid-range', sender: 'human', commits: [commit('human', 'invalid-subject')]
          ), valid: false)

          # The final line of a later queued event proves preceding events have
          # finished on both channels before checking silence and flushed logs.
          post_webhook('push', push_payload(
            'processing-barrier', sender: 'human', commits: [commit('human', 'barrier-human')]
          ))
          clients.each do |channel, client|
            client.wait_for_privmsg(from: BOT_NICK, target: channel, text: '/compare/processing-barrier', timeout: 60)
          end

          filtered = clients.fetch('#vpsfree').lines.join("\n")
          unfiltered = clients.fetch('#vpsadminos').lines.join("\n")
          expect(filtered).to include(
            'pushed 1 announced commit (1 ignored)', 'Human: mixed-human', '/compare/mixed-range',
            'force-pushed master from aaaaaaaaa to bbbbbbbbb', 'Human: force-human', '[webhooks] 1 announced commit'
          )
          expect(filtered).not_to include('mixed-ignored', 'all-ignored', 'force-ignored', 'ignored-issue', 'invalid-')
          expect(unfiltered).to include('mixed-ignored', 'mixed-human', 'all-ignored-subject', 'force-range', 'ignored-issue')
          expect(unfiltered).not_to include('force-human', 'invalid-')

          CHANNELS.each do |channel|
            %w[html yml].each do |format|
              # Logging follows sending; wait for the barrier to be flushed too.
              directory = "/var/lib/vpsfree-irc-bot/archive/#{format}/irc.test/#{channel}"
              irc.wait_until_succeeds("grep -R -q processing-barrier #{Shellwords.escape(directory)}", timeout: 30)
              log = channel_log(channel, format)
              expect(log).to include('mixed-human', 'mixed-range', 'processing-barrier')
              expect(log).not_to include('invalid-')
              if channel == '#vpsfree'
                expect(log).to include('announced commit (1 ignored)', 'force-human')
                expect(log).not_to include('mixed-ignored', 'all-ignored', 'force-ignored', 'ignored-issue')
              else
                expect(log).to include('mixed-ignored', 'all-ignored-subject', 'ignored-issue')
              end
            end
          end
        rescue StandardError, RSpec::Expectations::ExpectationNotMetError => error
          clients.each { |channel, client| warn "#{channel}: #{client.lines.last(30).inspect}" }
          begin
            _, output = irc.succeeds('journalctl -u vpsfree-irc-bot -n 80 --no-pager', timeout: 15)
            warn output
          rescue StandardError => diagnostic_error
            warn "Unable to read bot service log: #{diagnostic_error.message}"
          end
          raise error
        end
      end
    '';
  }
)
