#!/usr/bin/ruby
require 'rubygems'
require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/installed_app'
require 'google_drive'

# Backup controller
# Sync backup folder with google drive cloud service
class BackupController < ApplicationController
  # Google API auth client
  @client = nil

  # Connecting to Google API via oAuth2
  def self.auth
    # Authorizes with OAuth and gets an access token.
    # Initialize the client.
    @client = Google::APIClient.new(
      application_name: 'Backup application',
      application_version: '0.1.0'
    )

    # Load p12 auth key file
    @client.authorization = Signet::OAuth2::Client.new(
      token_credential_uri: 'https://accounts.google.com/o/oauth2/token',
      audience: 'https://accounts.google.com/o/oauth2/token',
      scope: 'https://www.googleapis.com/auth/drive',
      issuer: Rails.application.secrets.google_api_issuer,
      signing_key: apikey,
      person: Rails.application.secrets.google_api_sub
    )
    @client.authorization.fetch_access_token!
  end

  # Sync backup folder with google drive backup folder
  def self.sync_backup
    # First of all auth via Google
    auth

    # Make google drive calls
    gdrive
  end

  # Make drive calls
  def self.gdrive
    drive = @client.discovered_api('drive','v2');
    api_result = @client.execute(api_method: drive.files.list, 
                                 parameters: {q: "'" + Rails.application.secrets.google_drive_backup_folder + "' in parents"});
    #puts api_result.inspect
    files = api_result.data
    puts files.inspect
  end

  # Get p12 key file
  def self.apikey
    Google::APIClient::KeyUtils.load_from_pkcs12(
      File.join(Rails.root, 'config', 
                Rails.application.secrets.google_api_cert_file
      ),
      'notasecret'
    )
  end
end
