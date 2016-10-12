# frozen_string_literal: true

require_relative 'spec_helper'

include WebMock::API
WebMock.enable!

FB_API_URL = FaceGroup::FbApi::FB_API_URL
FB_TOKEN_URL = FaceGroup::FbApi::FB_TOKEN_URL

VCR.configure do |c|
  c.cassette_library_dir = CASSETTES_FOLDER
  c.hook_into :webmock

  c.filter_sensitive_data('ACCESS_TOKEN') do |interaction|
    uri = interaction.request.uri.to_s
    token = uri.match(/access_token=([^&\n]+)/)
    token[1] if token
  end

  c.filter_sensitive_data('ACCESS_TOKEN') do |interaction|
    body = interaction.response.body.to_s
    token = body.match(/access_token=([^&\n]+)/)
    token[1] if token
  end

  c.filter_sensitive_data('"access_token":"ACCESS_TOKEN"') do |interaction|
    body = interaction.response.body.to_s
    body.match(/\"access_token\":\"[^\"]*\"/)
  end

  c.filter_sensitive_data('CLIENT_ID') { CREDENTIALS[:client_id] }
  c.filter_sensitive_data('CLIENT_SECRET') { CREDENTIALS[:client_secret] }
end

# Prepare recordings
VCR.insert_cassette CASSETTE_FILE, record: :new_episodes
@fb_result = {}

access_token_response = HTTP.get(
  FB_TOKEN_URL,
  params: { client_id: CREDENTIALS[:client_id],
            client_secret: CREDENTIALS[:client_secret],
            grant_type: 'client_credentials' }
)
access_token_data = JSON.load(access_token_response.to_s)
access_token = access_token_data['access_token']

# Record group information response and result
group_response = HTTP.get(
  URI.join(FB_API_URL, CREDENTIALS[:group_id].to_s),
  params: { access_token: access_token }
)
group_results = JSON.load(group_response.body.to_s)
@fb_result[:group] = group_results

# Record group feed response and result
feed_response = HTTP.get(
  URI.join(FB_API_URL, "#{CREDENTIALS[:group_id]}/feed"),
  params: { access_token: access_token }
)
feed = JSON.load(feed_response)['data']
@fb_result[:feed] = feed

# Record id of feed postings with messages
posting_with_message_id = feed.find { |p| p['message'] }['id']
@fb_result[:posting_with_message_id] = posting_with_message_id

# Record posting response and result
posting_response = HTTP.get(
  URI.join(FB_API_URL, posting_with_message_id.to_s),
  params: { access_token: access_token }
)
posting = JSON.load(posting_response)
@fb_result[:posting] = posting

# Record posting attachment response and result
attachment_response = HTTP.get(
  URI.join(FB_API_URL, "#{posting_with_message_id}/attachments"),
  params: { access_token: access_token }
)
attachment = JSON.load(attachment_response)['data']
@fb_result[:attachment] = attachment

# Record results
File.write(RESULT_FILE, @fb_result.to_yaml)
VCR.eject_cassette
