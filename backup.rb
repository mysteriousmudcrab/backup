#Purpose:  Simple rsync backup script that only backups modified files.
# Author:  Andrew Perkins <andrew.perkins@cqumail.com>
#Version:  0.1.0 (19/07/2011)
#    git:  https://github.com/mysteriousmudcrab/backup
# Tested:  Ubuntu Linux (11.04 2.6.38-10-generic)
#          ruby 1.9.2p180 (2011-02-18 revision 30909) [x86_64-linux]
# 
#   Bugs:  >ö< backup paths cannot have spaces [fixed [again fixed]]
#          >1< does not yet sync a separate batch of files to cloud [fixed]
#          >2< does not yet accept command line arguments. [fixed]
#          >3< does not yet list largest 3 directories as a statistic at end
#          >4< does not attempt to locate rsync [fixed]
#          >5< does not run in separate 'nice' (low priority) thread [fixed]
#          >6< no FAT32 support, need to use --size-only if backing up to FAT32
#              http://ubuntuforums.org/showthread.php?t=87038&page=2
#          >7< 
#          >8< 
#          >9< 
#
################################################################################
class Backup
  attr_accessor :rsync_bin, :rsync_args, :backup_paths, :verbose, :verbose_args,
    :destination_paths, :exclude_list, :exclude_movies, :movie_types,
    :skipped_files
  
  def initialize(verbose = false, rsync_bin = '/usr/bin/rsync',
      exclude_movies = false, backup_paths = [], destination_paths = [])
    @movie_types = %w(avi mov divx mp4 mpg wmv rm)
    @rsync_bin = rsync_bin
    @rsync_args = %w(--archive --hard-links --delete --delete-excluded)
    @backup_paths = backup_paths
    @destination_paths = destination_paths
    @verbose_args = %w(--verbose --progress --human-readable)
    @verbose = verbose
    @exclude_movies = exclude_movies
    @exclude_list = []
    @skipped_files = []
    start if backup_paths and destination_paths
  end
  
################################################################################
# general helper methods
  
  # output an error message and exit with an error code
  def error(msg="Congratulations, an unknown error occurred!")
    puts "(EE) #{msg}"
    exit
  end
  
  def warn(msg="")
    puts "(WW) #{msg}"
  end
  
  # output a message
  def info(msg="")
    print "(II) #{msg}"
  end
  
  # keep the method for exiting in one place
  def exit
    Process.exit!
  end

  # read keyboard response, return true if response is y,Y or '' (return)
  # return true if not verbose
  def proceed?
    return true unless @verbose
    info "Proceed?  (<y>/n): "
    response = gets.chomp.gsub("\\n","")
    response.downcase == 'y' || response == ''
  end
  
################################################################################
# rsync helpers
  
  # does rsync exist?
  def rsync?
    result = File.readable?(get_rsync_bin)
    error "No rsync found!  (expecting #{get_rsync_bin})" unless result
    result
  end
  
  # get rsync bin (attempt to locate if it does not exist or is not accessible)
  def get_rsync_bin
    return @rsync_bin if File.readable? @rsync_bin
    `which rsync`.chomp.gsub("\\n","")
  end
  
  # build rsync args string
  def get_rsync_args
    args = @rsync_args
    args.concat @verbose_args if @verbose
    args_str = ""
    args.each do |a|
      args_str = "#{args_str} #{a}"
    end
    args_str
  end
  
  # build the command to run
  def get_command
    "#{get_rsync_bin} #{get_rsync_args} #{get_exclude_list} " \
        "#{get_backup_list} '#{get_destination_path}'"
  end
################################################################################
# helper methods for the list of files and directories to be backed up
  
  # build backup list for rsync...
  def get_backup_list
    list = nil
    @skipped_files = [] # don't want this to append every time method is called
    @backup_paths.each do |back|
      path = File.expand_path back
      if File.readable? path then list = "#{list} '#{path}'"
      else @skipped_files.push path
      end
    end
    list
  end
  
  def output_backup_list
    info "Backup list:\n"
    @backup_paths.each do |back| 
      info " => #{File.expand_path back}\n"
    end
  end
  
  # is there at least 1 directory or file to backup?
  def backup_list?
    get_backup_list != nil
  end
  
  # build exclude list...
  def get_exclude_list
    new_exclude_list = nil
    @exclude_list.each do |ex|
      new_exclude_list = "#{new_exclude_list} --exclude '#{ex}'"
    end
    new_exclude_list
  end
  
  # list inaccessible files or directories
  def list_inaccessible
    msg = "#{@skipped_files.size} files/directories inaccessible."
    msg = "#{msg} Try running this script as root." if skipped_files.count > 0
    info "#{msg}\n"
    @skipped_files.each do |sk|
      warn " => '#{sk}'\n"
    end
  end
  
################################################################################
# helper methods for the backup destination
  
  # search for the first backup destination
  def get_destination_path
    @destination_paths.each do |dest|
      path = File.expand_path dest
      return path if File.readable? path # found!
    end
    nil
  end
  
  # is there a valid backup destination path?
  def destination_path?
    get_destination_path != nil
  end
  
################################################################################
# main logic
  
  # start backup if everything is OK
  def start
    return unless rsync? and backup_list? and destination_path?
    output_backup_list
    list_inaccessible
    info "Backing up to: '#{get_destination_path}'\n"
    info "About to run command: #{get_command}\n"
    return unless proceed?
    do_backup
  end
  
  private
  
  # perform backup
  def do_backup
    info "Proceeding with backup...\n"
    start_time = Time.new
    IO.popen get_command do |cmd|
      until cmd.eof?
       puts cmd.readline
      end
    end
    duration = Time.new.to_i - start_time.to_i
    hrs = duration / 3600
    min = (duration / 60) % 60
    sec = duration % 60
    duration_s = "%02d:%02d:%02d" % [hrs, min, sec]
    puts ''
    info "Time elapsed: #{duration_s}\n"
    rescue Exception => e
      warn "Backup terminated!\n"
  end
end
