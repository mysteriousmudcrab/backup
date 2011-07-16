#!/usr/bin/ruby1.9.1
#!/usr/bin/ruby

#Purpose:  Simple rsync backup script that only backups modified files.
# Author:  Andrew Perkins <andrew.perkins@cqumail.com>
#Version:  0.0.3 (16/07/2011)
# Tested:  Ubuntu Linux (11.04 2.6.38-10-generic)
#          ruby 1.9.2p180 (2011-02-18 revision 30909) [x86_64-linux]
# 
#   Bugs:  >ö< backup paths cannot have spaces [fixed]
#          >1< does not yet sync a separate batch of files to cloud.
#          >2< does not yet accept command line arguements.
#          >3< does not yet list largest 3 directories as a statistic at end.
#          >4< does not attempt to locate rsync
#          >5< does not run in separate 'nice' (low priority) thread [fixed]
#          >6< 
#          >7< 
#          >8< 
#          >9< 

# 
################################################################################
# Config:
debug_mode = false # if true, do not execute rsync command (show proposed cmd)

# use the first location that exists.
# for example: first location is removable media, so if this is not present,
# use the second, or third, etc. location.
destination_list = [
  '/media/landfill/Andy/backup',
  '/media/10GB/backup',
  '/windows/backup/',
  '/back up/',  # test spaces
  '~/backup/',
]

# the files or directories to backup.
backup_list = [
  '~/Documents/',
  '~/Pictures/',
  '~/CQU/',
  '~/Desktop/',
#  '~/bin/',
  '~/.mozilla/',
  '~/.mysql/',
  '/srv/www/',
  '/var/lib/mysql/',
  '/etc/',
  '~/Ubuntu One/' # test spaces
]
backup_list.push(File.expand_path($0)) # include this script!

# files and directorys to exclude from backups.
# for example:  we don't necessarily want .mozilla Cache folders.
exclude_list= [
  '/.Trash-1000/',
  '/lost+found',
  '*/*Cache*/*',
  '*/*cache*/*',
  '*.mov',
  '*.avi',
  '*.mp4',
  '*.mpg',
  '*.wmv',
]

rsync_bin   = "/usr/bin/rsync"
rsync_args  = "--archive --hard-links --verbose --human-readable --stats " \
              "--itemize-changes --progress --delete --delete-excluded"

# end 'config'
################################################################################
# helper methods...

# output an error message and exit with an error code
def error(msg="Congratulations, an unknown error occurred!", code=1)
  puts "(EE) #{msg}"
#  puts `ruby -v`
  Process.exit! code
end

# output a message
def info(msg="")
  print "(II) #{msg}"
end

# end helper methods
################################################################################
# main program...

skipped_file_list = []

# output ruby version...
info `ruby -v`

# does rsync exist?
error "Error: Could not find rsync!",2 unless File.exists?(rsync_bin)

# search for the first destination backup media/location that exists and use
destination_new = nil
destination_list.each { |d|
  #info "d: #{d} (#{File.expand_path(d)})\n"
  if File.exists? d then
    destination_new = d
    info "Backing up to: '#{d}'\n"
    break
  end
}
error "Error: No suitable backup destination found!",4 unless destination_new

# build exclude list...
new_exclude_list = ""
exclude_list.each {|ex|
  new_exclude_list = "#{new_exclude_list} --exclude '#{ex}'"
}

# build backup list...
new_backup_list = ""
backup_list.each {|d|
  # silently ignore files that do not exists in backup list
  path = File.expand_path(d)
  if File.readable?(path) then
    new_backup_list = "#{new_backup_list} '#{path}'"
    info " => '#{path}'\n"
  else
    skipped_file_list.push path
  end
}

# build the command to run...
cmd = "#{rsync_bin} #{rsync_args} #{new_exclude_list} #{new_backup_list} " \
     "#{destination_new}"
info "About to run: #{cmd}\n"

#bail here if in debug mode
error "Debug mode: no backup created!",8 if debug_mode

# Read keyboard response, abort if n
info "Proceed?  (y/n): "
response = gets.chomp.gsub("\\n","")
error "Backup aborted!",16 unless response.downcase == 'y' || response == ''

# awaken the beast...
info "Proceeding with backup...\n"
IO.popen cmd do |fd|
  until fd.eof?
    puts fd.readline
  end
end

# list inaccessable files or directories
puts "" # newline
info "#{skipped_file_list.size} files/directories inaccessable.\n"
skipped_file_list.each { |sk|
  info " => '#{sk}'\n"
}
info "Try running this script as root.\n" if skipped_file_list.count > 0
