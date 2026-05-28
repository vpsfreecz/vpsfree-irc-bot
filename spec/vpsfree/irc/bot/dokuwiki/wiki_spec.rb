# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VpsFree::Irc::Bot::DokuWiki::Wiki do
  let(:bot) { instance_double(Cinch::Bot) }

  it 'builds page URLs for configured rewrite modes' do
    wiki = described_class.new(bot, url: 'https://kb.example/', rewrite: 0)
    rewritten = described_class.new(bot, url: 'https://kb.example/', rewrite: 2, namespace_slash: true)

    expect(wiki.page_url('kb:start')).to eq('https://kb.example/doku.php?id=kb:start')
    expect(rewritten.page_url('kb:start')).to eq('https://kb.example/doku.php/kb/start')
  end

  it 'builds diff URLs from adjacent page revisions' do
    wiki = described_class.new(bot, url: 'https://kb.example/', rewrite: 0)

    expect(
      wiki.diff_url(
        'kb:start',
        { 'version' => 1 },
        { 'version' => 2 }
      )
    ).to eq('https://kb.example/doku.php?id=kb:start&do=diff&rev2[0]=1&rev2[1]=2&difftype=sidebyside')
  end

  it 'extracts maintainer IRC nicks from page HTML' do
    wiki = described_class.new(bot, url: 'https://kb.example/')
    server = instance_double(XMLRPC::Client)
    wiki.instance_variable_set(:@server, server)

    allow(server).to receive(:call)
      .with('wiki.getPageHTML', 'kb:start')
      .and_return(<<~HTML)
        <ul class="maintainers">
          <li><a data-page-exists="1" data-page-id="user:alice"> Alice </a></li>
          <li><a data-page-exists="0"> Bob </a></li>
        </ul>
      HTML
    allow(server).to receive(:call)
      .with('wiki.getPageHTML', 'user:alice')
      .and_return(<<~HTML)
        <div class="maintainer">
          <table><tr class="irc"><td>alice_irc</td></tr></table>
        </div>
      HTML

    expect(wiki.fetch_maintainers('kb:start')).to eq([
                                                       { nick: 'Alice', irc: 'alice_irc' },
                                                       { nick: 'Bob' }
                                                     ])
  end
end
