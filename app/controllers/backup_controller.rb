# Backup controller
# Sync backup folder with google drive cloud service
require "rubygems"
require "google/api_client"
require 'google/api_client/client_secrets'
require 'google/api_client/auth/installed_app'
require "google_drive"

class BackupController < ApplicationController
	def self.sync_backup
		puts "Here I am!"
	end

# Authorizes with OAuth and gets an access token.

# Initialize the client.
client = Google::APIClient.new(
	:application_name => 'Bakup application',
	:application_version => '0.1.0'
)

# Load p12 auth key
key = Google::APIClient::KeyUtils.load_from_pkcs12(
	File.join(Rails.root,'config','google_client.p12'), 'notasecret')

client.authorization = Signet::OAuth2::Client.new(
	:token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
	:audience => 'https://accounts.google.com/o/oauth2/token',
	:scope => 'https://www.googleapis.com/auth/prediction',
	:issuer => Rails.application.secrets.google_api_issuer,
	:signing_key => key
)
client.authorization.fetch_access_token!
puts "token: " + client.access_token

#client = Google::APIClient.new
#auth = client.authorization
#auth.client_id = Rails.application.secrets.google_apiclient_id
#auth.client_secret = Rails.application.secrets.google_api_client_secret
#auth.scope =
#	"https://www.googleapis.com/auth/drive" 
	#                 auth.redirect_uri = "urn:ietf:wg:oauth:2.0:oob"
	#                 print("1. Open this page:\n%s\n\n" % auth.authorization_uri)
	#                 print("2. Enter the authorization code shown in the page: ")
	#                 auth.code = $stdin.gets.chomp
	#                 auth.fetch_access_token!
	#                 access_token = auth.access_token
	#
	#                 # Creates a session.
	#                 session = GoogleDrive.login_with_oauth(access_token)
	#
	#                 # Gets list of remote files.
	#                 for file in session.files
	#                   p file.title
	#                   end
end
