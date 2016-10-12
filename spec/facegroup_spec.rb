# frozen_string_literal: true
require 'minitest/autorun'
require 'minitest/rg'
require 'vcr'
require 'webmock'

require_relative 'spec_helper.rb'

FB_RESULT = YAML.load(File.read(RESULT_FILE))

describe 'FaceGroup specifications' do
  VCR.configure do |c|
    c.cassette_library_dir = CASSETTES_FOLDER
    c.hook_into :webmock

    c.filter_sensitive_data('<ACCESS_TOKEN>') { CREDENTIALS[:access_token] }
    c.filter_sensitive_data('<ACCESS_TOKEN_ESCAPED>') do
      URI.escape(CREDENTIALS[:access_token])
    end
    c.filter_sensitive_data('<CLIENT_ID>') { CREDENTIALS[:client_id] }
    c.filter_sensitive_data('<CLIENT_SECRET>') { CREDENTIALS[:client_secret] }
  end

  before do
    VCR.insert_cassette CASSETTE_FILE, record: :new_episodes

    @fb_api = FaceGroup::FbApi.new(
      client_id: CREDENTIALS[:client_id],
      client_secret: CREDENTIALS[:client_secret]
    )

    @posting_with_msg_id = FB_RESULT['posting']['id']
  end

  after do
    VCR.eject_cassette
  end

  it 'should be able to get a new access token' do
    fb_api = FaceGroup::FbApi.new(
      client_id: CREDENTIALS[:client_id],
      client_secret: CREDENTIALS[:client_secret]
    )

    fb_api.access_token.length.must_be :>, 0
  end

  it 'should be able to open a Facebook Group' do
    group = FaceGroup::Group.new(
      @fb_api,
      group_id: CREDENTIALS[:group_id]
    )

    group.name.length.must_be :>, 0
  end

  it 'should get the latest feed from an group' do
    group = FaceGroup::Group.new(
      @fb_api,
      group_id: CREDENTIALS[:group_id]
    )

    feed = group.feed
    feed.count.must_be :>, 10
  end

  it 'should get information about postings on the feed' do
    group = FaceGroup::Group.new(
      @fb_api, group_id: CREDENTIALS[:group_id]
    )

    posting_with_msg = group.feed.find { |p| p.id == @posting_with_msg_id }
    posting_with_msg.message.must_equal FB_RESULT['posting']['message']
  end

  it 'should find attachments in postings' do
    group = FaceGroup::Group.new(
      @fb_api, group_id: CREDENTIALS[:group_id]
    )

    posting_with_msg = group.feed.find { |p| p.id == @posting_with_msg_id }
    posting_with_msg.attachment[:description].must_equal(
      FB_RESULT['posting']['attachment'].first['description']
    )
  end
end
