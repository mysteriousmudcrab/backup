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
#          >6< 
#          >7< 
#          >8< 
#          >9< 
#
# 
################################################################################

class Backup
  attr_accessor :rsync_bin, :rsync_args, :backup_paths, :verbose, :verbose_args,
    :destination_paths, :exclude_list, :exclude_movies, :movie_types,
    :skipped_files
  
  def initialize(verbose = true, rsync_bin = '/usr/bin/rsynck',
      exclude_movies = false, backup_paths = [], destination_paths = [])
    @movie_types = %w(avi mov divx mp4 mpg wmv rm)
    @rsync_bin = rsync_bin
    @rsync_args = %w(--archive --hard-links --delete --delete-excluded)
    @backup_paths = backup_paths
    @destination_paths = destination_paths
    @verbose_args = %w(--verbose --stats --itemize-changes --progress 
        --human-readable)
    @verbose = verbose
    @exclude_movies = exclude_movies
    @exclude_list = []
    @skipped_files = []
    start if backup_paths and destination_paths
  end
  
  # output an error message and exit with an error code
  def error(msg="Congratulations, an unknown error occurred!")
    puts "(EE) #{msg}" if @verbose
    exit
  end
  
  def warn(msg="")
    puts "(WW) #{msg}" if @verbose
  end
  
  # output a message
  def info(msg="")
    print "(II) #{msg}" if @verbose
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
  
  # does rsync exist?
  def rsync?
    result = File.readable?(get_rsync_bin)
    error "No rsync found!  (expecting #{get_rsync_bin})" unless result
    result
  end
  
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
  
  # search for the first destination backup media/location that exists and use
  def get_destination_path
    @destination_paths.each do |dest|
      path = File.expand_path dest
      return path if File.readable? path # found!
    end
    nil
  end
  
  # is there a valid backup media path?
  def backup_media_path?
    get_destination_path != nil
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
  
  # build the command to run
  def get_command
    "#{get_rsync_bin} #{get_rsync_args} #{get_exclude_list} " \
        "#{get_backup_list} '#{get_destination_path}'"
  end
  
  # start backup if everything is OK
  def start
    return unless rsync? and backup_list? and backup_media_path?
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
    IO.popen get_command do |cmd|
      until cmd.eof?
       puts cmd.readline
      end
    end 
    rescue Exception => e
      warn "Backup terminated!\n"
  end # do_backup
end # class

