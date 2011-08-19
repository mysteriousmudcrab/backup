#!/usr/bin/ruby
#Purpose:  Simple rsync backup script that only backups modified files.
#          Works on unix and FAT32/NTFS filesystems using different rsync params
# Author:  Andrew Perkins <andrew.perkins@cqumail.com>
#Version:  0.1.2 (15/08/2011)
#    git:  https://github.com/mysteriousmudcrab/backup

# Tested:  Ubuntu Linux (11.04 2.6.38-10-generic)
#          ruby 1.9.2p180 (2011-02-18 revision 30909) [x86_64-linux]
# 
#   Bugs:  >ö< backup paths cannot have spaces [fixed [again fixed]]
#          >1< does not yet sync a separate batch of files to cloud [fixed]
#          >2< does not yet accept command line arguments. [in progress]
#          >3< does not yet list largest 3 dirs as a statistic at end [abandon?]
#          >4< does not attempt to locate rsync [fixed]
#          >5< does not run in separate 'nice' (low priority) thread [fixed]
#          >6< no FAT32 support, need to use --size-only if backing up to FAT32
#              http://ubuntuforums.org/showthread.php?t=87038&page=2
#              [fixed]
#          >7< no NFTS support, cannot use --archive
#              http://ubuntuforums.org/showthread.php?t=820425 [fixed]
#          >8< 
#          >9< 
#
################################################################################
class Backup
  attr_accessor :rsync_args, :backup_paths, :backup_dests, :verbose,
     :verbose_args, :exclude, :show_backup_list, :show_inaccessable
    @skipped_files = []
    
  def initialize(verbose = true, backup_paths = [], backup_dests = [])
    #puts "#{verbose} #{backup_paths.to_s} #{backup_dests.to_s}"
    set_defaults
    @verbose = verbose
    @backup_paths = backup_paths
    @backup_dests = backup_dests
    start unless backup_paths.empty? or backup_dests.empty?
  end
  
  def set_defaults
    @rsync_bin = '/usr/bin/rsync'
    # preserving --hard-links is expensive http://linux.die.net/man/1/rsync
    @rsync_args = %w(--archive --delete --delete-excluded)
    @rsync_args_compat = %w(--devices --specials --links --size-only)
    # http://ubuntuforums.org/showthread.php?t=820425
    @rsync_args_compat.push "--modify-window=1", "--recursive"
    @verbose_args = %w(--verbose --progress --human-readable)
    @exclude = [ '/.Trash-1000/', '/lost+found', '*/*Cache*/*', '*/*cache*/*']
    @skipped_files = []
    @show_backup_list = false
    @show_inaccessable = true
  end
  
######################################################### GENERAL HELPER METHODS
  
  # output an error message and exit
  def error(msg="Congratulations, an unknown error occurred!")
    puts "(EE) #{msg}"
    exit
  end
  
  def warn(msg="")
    puts "(WW) #{msg}"
  end
  
  # output a message
  def info(msg="")
    puts "(II) #{msg}"
  end
  
  # keep the method for exiting in one place
  def exit(msg="")
    puts
    warn "Backup aborted! #{msg}"
    Process.exit!
  end
  
  # output a list in a standard format
  def output_list(heading = "", list = [])
     info heading
     list.each { |l| info "  => #{l}" }
  end

  # read keyboard response, return true if response is y,Y or '' (return)
  # if not in verbose mode, return true
  def proceed?
    return true unless @verbose
    print "(II) Proceed? <y>/n: "
    response = gets.chomp.gsub("\\n","")
    response.downcase == 'y' || response == ''
    rescue Exception => e
      exit
  end
  
  # return a string containing the filename of this class
  def class_name
    File.expand_path caller[0].split(":")[0]
  end
################################################################## RSYNC HELPERS
  
  # does rsync exist?
  def rsync?
    result = File.readable? rsync
    error "No rsync found!  (expecting #{rsync})" unless result
    result
  end
  
  # get rsync bin (attempt to locate if it does not exist or is not accessible)
  def rsync
    return @rsync_bin if File.readable? @rsync_bin
    `which rsync | head -n 1`.chomp.gsub("\\n","") # Bug: won't work on windows
  end
  
  # build rsync args string
  def args
    arg = @rsync_args
    arg.concat @verbose_args if @verbose
    result = ""
    arg.each { |a| result = "#{result} #{a}" }
    result
  end
  
  # build the command to run
  def command
    "#{rsync} #{args} #{exclude_list} #{backup_list} '#{backup_dest}'"
  end
#################################################################### BACKUP TEST
  # TEST: does a small test backup (this file) succeed?  return true if the
  # destination file modification time < 3 seconds ago,and the file sizes match,
  # ensuring that it was not just a blank file created
  def test_succeeds?
    info "Performing test backup... (this file)"
    do_backup "#{rsync} #{args} \'#{class_name}\' \'#{backup_dest}\'", false
    destination = File.join(backup_dest, File.basename(class_name))
    File.stat(destination).size == File.stat(class_name).size and
        File.stat(destination).mtime > (Time.now - 3)
  end
########################################################### BACKUP FILES/FOLDERS
# helper methods for the list of files and folders to be backed up
  
  # build backup list for rsync...
  def backup_list
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
  
  # build exclude list...
  def exclude_list
    result = nil
    @exclude.each { |ex| result = "#{result} --exclude '#{ex}'" }
    result
  end
  
  # list inaccessible files or folders (but not subfolders)
  def show_inaccessible
    warn "#{@skipped_files.size} files/folders inaccessible " + \
        "(try running as root):"
    @skipped_files.each { |sk| warn "  => #{sk}" }
  end
############################################################# BACKUP DESTINATION
# helper methods for the backup destination
  
  # search for the first backup destination
  def backup_dest
    @backup_dests.each do |dest|
      path = File.expand_path dest
      return path if File.readable? path # found!
    end
    nil
  end
########################################################################### MAIN
# main logic
  
  # start backup if everything is OK
  def start
    init # will exit if checks fail
    info "Backing up to: '#{backup_dest}'"
    info "About to run command: #{command}"
    exit unless proceed?
    info "Proceeding with backup, please wait..."
    start_time = Time.new
    do_backup                                                     # START BACKUP
    secs = Time.new.to_i - start_time.to_i
    duration = "%02d:%02d:%02d" % [secs / 3600, (secs / 60) % 60, secs % 60]
    puts ''
    info "Backup complete!  Time elapsed: #{duration}"
  end
  
  def init
    error "No rsync binary found!" unless rsync?
    error "No files or folders to backup!" if backup_list == nil
    error "No backup destination!" if backup_dest == nil
    compatibility_fix unless test_succeeds?
    output_list "Backup list:", @backup_paths if @show_backup_list
    show_inaccessible if @show_inaccessable
  end
  
  private
  
  # perform backup
  def do_backup(args=command, verbose=false)
    IO.popen args do |cmd|
      until cmd.eof?
       buffer = cmd.readline
       puts buffer if verbose
      end
    end
    rescue Exception => e
      exit
  end
  
  # remove --archive arg and replace with compatible args
  def compatibility_fix
    warn "Test backup failed.  Activating NTFS/FAT32 compatibility mode..."
    @rsync_args.delete "--archive"
    @rsync_args_compat.each do |c|
      @rsync_args.push c unless @rsync_args.include? c
    end
  end
end

# start backup if arguements have been specified
# TODO:  if verbose (1st arg = true), gets (in proceed?) creates an exception
b = Backup.new false, ARGV[1].split(',').collect! {|f| "#{f}"}, 
    ARGV[2].split(',').collect! {|f| "#{f}"} if ARGV[2]
