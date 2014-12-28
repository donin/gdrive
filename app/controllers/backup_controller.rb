#!/usr/bin/ruby
require 'rubygems'
require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/installed_app'
require 'ruby-filemagic'

# Backup controller
# Sync backup folder with google drive cloud service
class BackupController < ApplicationController
  # Google API auth client & drive api
  @client, @drive = nil

  # Rails application secrets
  @secrets = Rails.application.secrets

  # Connecting to Google API via oAuth2
  def self.auth
    # Authorizes with OAuth and gets an access token.
    # Initialize the client.
    @client = Google::APIClient.new(
      application_name: 'Gdrive backup application',
      application_version: '0.6.0'
    )

    # Load p12 auth key file
    @client.authorization = Signet::OAuth2::Client.new(
      oauth2_options
    )
    @client.authorization.fetch_access_token!
    @drive = @client.discovered_api('drive', 'v2')
  end

  # Get oAuth2 login options
  def self.oauth2_options
    {
      token_credential_uri: 'https://accounts.google.com/o/oauth2/token',
      audience: 'https://accounts.google.com/o/oauth2/token',
      scope: 'https://www.googleapis.com/auth/drive',
      issuer: @secrets.gapi_issuer,
      signing_key: apikey,
      person: @secrets.gapi_sub
    }
  end

  # Sync backup folder with google drive backup folder
  def self.sync_backup
    # First of all auth via Google
    auth

    # Start upload workflow
    upload_files

    # Cleanup remote dir
    clear_old_remote_files
  end

  # Upload backup files flow
  def self.upload_files
    # sort files by modification date (oldest first)
    local_files.each do |f|
      upload!(f) unless skip_upload?(f)
    end
  end

  # Upload file to google drive folder
  def self.upload!(f)
    puts 'uploading ' + File.basename(f) +
      ' (' + Filesize.from(File.size(f).to_s + ' B').pretty + ')'

    @client.execute(
      api_method: @drive.files.insert,
      parameters: { uploadType: 'multipart' },
      body_object: upload_meta(f),
      media: upload_media(f)
    )
  end

  # Prepare file for upload
  def self.upload_media(f)
    Google::APIClient::UploadIO.new(f, mime(f))
  end

  # Return meta hash for upload request
  def self.upload_meta(f)
    {
      title: File.basename(f),
      description: 'isew amazon ec2 backup file',
      parents: [{ id: @secrets.gdrive_backup_folder }]
    }
  end

  # Get file mime type
  def self.mime(f)
    FileMagic.new(FileMagic::MAGIC_MIME).file(f)
  end

  # Upload file or not?
  def self.skip_upload?(file)
    rtitles = [] # array of remote file titles
    remote_files.each { |f| rtitles.push f.title }
    # Skip upload if file already exists in remote folder
    rtitles.include? File.basename(file)
  end

  # Check remote folder limits
  # Move old remote files to trash
  def self.clear_old_remote_files
    rfiles = remote_files # get all remote files
    limit = @secrets.gdrive_files_limit
    return if rfiles.count < limit

    # Get candidates for delete
    # Sort by create date DESC (newest first)
    # and get only last `limit` files
    ok = rfiles.sort_by { |a| a.createdDate.to_i }.last(limit)

    # Remove the difference between remote files and ok files
    remove_files!(rfiles - ok)
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
    limit = @secrets.gdrive_files_limit
    lfiles = Dir["#{@secrets.backup_folder}/*tar.bz2"]
    lfiles.sort_by { |f| File.ctime(f) }.last(limit).reverse!
  end

  # Get all files in the backup directory
  def self.remote_files
    dir_id = @secrets.gdrive_backup_folder
    q = {
      q: "'#{dir_id}' in parents and trashed = false",
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
