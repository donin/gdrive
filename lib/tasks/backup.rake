# Task backup
# sync backup folder with google drive cloud storage
task :backup => :environment do
  puts "running backup..."
  BackupController.sync_backup
  puts "done"
end
