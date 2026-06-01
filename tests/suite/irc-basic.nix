import ../make-test.nix (
  {
    pkgs,
    botPackage,
    ...
  }:
  let
    hostForwardName = "irc-basic";
  in
  {
    name = "irc-basic";

    description = ''
      Boot ngIRCd with vpsfree-irc-bot and test IRC commands that do not need
      vpsAdmin or external internet services.
    '';

    tags = [
      "ci"
      "irc"
      "light"
    ];

    machines = {
      irc = import ./common.nix {
        inherit
          pkgs
          botPackage
          hostForwardName
          ;
      };
    };

    testScript = ''
      configure_examples do |config|
        config.default_order = :defined
      end

      CHANNEL = '#vpsfree'
      BOT_NICK = 'vpsfbot'

      alice = nil
      bob = nil

      def irc_port
        IrcBotHostfwdPorts.port('${hostForwardName}')
      end

      def connect_client(nick)
        IrcBotClient.connect(port: irc_port, nick: nick, channel: CHANNEL)
      end

      before(:suite) do
        irc.start
        irc.wait_until_succeeds("ip -4 addr show dev eth0 | grep -q '10\\.0\\.2\\.'")
        irc.wait_for_service('ngircd')
        irc.wait_for_service('vpsfree-irc-bot')

        alice = connect_client('alice')
        bob = connect_client('bob')

        alice.wait_for_names_include(BOT_NICK)
        alice.command('!ping')
        alice.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: 'pong')
      end

      after(:suite) do
        [alice, bob].compact.each(&:close)
      end

      describe 'basic commands' do
        it 'renders private help' do
          helper = connect_client('helper')

          begin
            helper.command('help', target: BOT_NICK)
            helper.wait_for_privmsg(from: BOT_NICK, target: 'helper', text: 'vpsFree.cz IRC Bot')
            helper.wait_for_privmsg(from: BOT_NICK, target: 'helper', text: 'Private commands:')
          ensure
            helper.close
          end
        end

        it 'renders command-specific help' do
          alice.command('help ping', target: BOT_NICK)
          alice.wait_for_privmsg(from: BOT_NICK, target: 'alice', text: 'Command ping')
          alice.wait_for_privmsg(from: BOT_NICK, target: 'alice', text: 'Private: ping')
        end

        it 'answers ping in channel and private messages' do
          alice.command('!ping')
          alice.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: 'pong')

          alice.command('ping', target: BOT_NICK)
          alice.wait_for_privmsg(from: BOT_NICK, target: 'alice', text: 'pong')
        end

        it 'reports uptime and command counters' do
          alice.command('!uptime')
          alice.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: 'Uptime:')
          alice.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: 'Connected:')
          alice.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: 'Processed')
        end
      end

      describe 'archive command' do
        it 'returns archive URLs and validates selector arguments' do
          alice.command('!archive')
          alice.wait_for_privmsg(
            from: BOT_NICK,
            target: CHANNEL,
            text: 'http://archive.test/irc.test/%23vpsfree/'
          )

          alice.command('!archive today')
          alice.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: 'http://archive.test/')

          alice.command('!archive yesterday')
          alice.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: "'which' must be empty or 'today'")
        end
      end

      describe 'lastlog command' do
        it 'returns recent channel messages privately' do
          alice.command('message for lastlog')
          alice.command('!lastlog 2')

          alice.wait_for_privmsg(from: BOT_NICK, target: 'alice', text: "Last 2 messages from '#{CHANNEL}':")
          alice.wait_for_privmsg(from: BOT_NICK, target: 'alice', text: 'message for lastlog')
        end
      end

      describe 'greeter command' do
        it 'greets present users and rejects invalid targets' do
          alice.command('!greet bob')
          alice.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: "bob: Hi, welcome to #{CHANNEL}.")

          alice.command('!greet missing')
          alice.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: "User 'missing' is not in channel")

          alice.command('!greet alice')
          alice.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: "I doubt that's necessary.")

          alice.command("!greet #{BOT_NICK}")
          alice.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: "I'd rather not")
        end
      end

      describe 'mute commands' do
        it 'changes and reports mute state' do
          alice.command('!muted?')
          alice.wait_for_action(from: BOT_NICK, target: CHANNEL, text: 'is not muted')

          alice.command('!mute')
          alice.wait_for_action(from: BOT_NICK, target: CHANNEL, text: 'is muted until')

          alice.command('!unmute')
          alice.wait_for_action(from: BOT_NICK, target: CHANNEL, text: 'is free again')

          alice.command('!mute with nonsense')
          alice.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: "Invalid argument type: 'with'")
        end
      end

      describe 'rank commands' do
        it 'tracks messages, karma, rank and top output' do
          bob.command('hello from bob')
          alice.command('bob++')
          alice.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: "bob's karma increased to 1")

          bob.command('!rank')
          bob.wait_for_privmsg(from: BOT_NICK, target: CHANNEL, text: 'Your rank is')

          alice.command('!top 2')
          alice.wait_for_privmsg(from: BOT_NICK, target: 'alice', text: "Top 2 users from #{CHANNEL}:")
          alice.wait_for_privmsg(from: BOT_NICK, target: 'alice', text: 'bob')
        end
      end
    '';
  }
)
