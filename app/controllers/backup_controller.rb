#!/usr/bin/ruby
require 'rubygems'
require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/installed_app'

# Backup controller
# Sync backup folder with google drive cloud service
class BackupController < ApplicationController
  # Google API auth client
  @client = nil

  # Discover Google Drive API v2
  @drive = nil

  # Rails application secrets
  @secrets = Rails.application.secrets

  # Connecting to Google API via oAuth2
  def self.auth
    # Authorizes with OAuth and gets an access token.
    # Initialize the client.
    @client = Google::APIClient.new(
      application_name: 'Gdrive backup application',
      application_version: '0.2.0'
    )

    # Load p12 auth key file
    @client.authorization = Signet::OAuth2::Client.new(
      token_credential_uri: 'https://accounts.google.com/o/oauth2/token',
      audience: 'https://accounts.google.com/o/oauth2/token',
      scope: 'https://www.googleapis.com/auth/drive',
      issuer: @secrets.gapi_issuer,
      signing_key: apikey,
      person: @secrets.gapi_sub
    )
    @client.authorization.fetch_access_token!
    @drive = @client.discovered_api('drive', 'v2')
  end

  # Sync backup folder with google drive backup folder
  def self.sync_backup
    # First of all auth via Google
    auth

    # Clean up remote backup folder
    clear_old_remote_files

    # Get all files in the local backup folder
  end

  # Upload backup files
  def self.upload_files
    # sort files by modification date (oldest first)
    lfiles = local_files.sort_by { |f| File.new(f).mtime }
    lfiles.each do |f| # for each file
      next if skip_upload?(f)
      puts 'uploading '+ File.basename(f) + 
        ' (' + Filesize.from(File.size(f).to_s +' B').pretty + ')' 
      # upload!(f)
    end
  end

  # Upload file or not?
  def self.skip_upload?(file)
    remote_files.select { |k,v|  k == 'title' && v == File.basename(f) }
  end

  # Check remote folder limits
  # Move old remote files to trash
  def self.clear_old_remote_files
    rfiles = remote_files # get all remote files
    limit = @secrets.gdrive_files_limit
    return if rfiles.count < limit
    # Get candidates for delete
    ok = rfiles.sort_by { |a| a.createdDate.to_i }.reverse[0..limit-1]
    remove_files!(rfiles-ok)
  end

  # Remove files from google drive directory
  def self.remove_files!(files)
    files.each do |f|
      q = { fileId: f.id }
      puts "remove file: #{f.title}"
      @client.execute(api_method: @drive.files.trash, parameters: q)
    end
  end

  # Get local backup files
  def self.local_files
    Dir["#{@secrets.backup_folder}/*tar.bz2"]
  end

  # Get all files in the backup directory
  def self.remote_files
    q = { q: "'#{@secrets.gdrive_backup_folder}' in parents " + 
          " and trashed = false ",
          fields: 'items(createdDate,fileSize,id,mimeType,title)'
    }
    api_result = @client.execute(api_method: @drive.files.list, parameters: q)
    api_result.data.items
  end

  # Get p12 key file
  def self.apikey
    Google::APIClient::KeyUtils.load_from_pkcs12(
      File.path(@secrets.gapi_cert_file),
      'notasecret'
    )
  end
end
