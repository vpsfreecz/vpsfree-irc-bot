# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VpsFree::Irc::Bot::UrlMarker do
  subject(:marker) { described_class.allocate }

  it 'formats byte sizes using binary units' do
    expect(marker.send(:unitize, 2048)).to eq('2.0 KiB')
    expect(marker.send(:unitize, 512)).to eq('512 bytes')
  end

  it 'extracts and normalizes HTML titles' do
    doc = Nokogiri::HTML("<html><head><title>Hello\nworld</title></head></html>")

    expect(marker.send(:title, doc)).to eq('Hello world')
  end

  it 'stops reading oversized response bodies' do
    response = instance_double(Net::HTTPResponse)
    allow(response).to receive(:read_body).and_yield('hello').and_yield(' world')

    expect { marker.send(:read_body, response, 5) }
      .to raise_error(described_class::FetchError, 'Response is too large (11 bytes)')
  end
end
