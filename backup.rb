#!/usr/bin/ruby
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
#          >3< does not yet list largest 3 dirs as a statistic at end [abandon]
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
  attr_accessor :rsync_args, :backup_paths, :verbose, :verbose_args,
    :backup_dests, :exclude, :skipped_files, :show_backup_list, 
    :show_inaccessable, :prompt
  
  def initialize(verbose = true, backup_paths = [], backup_dests = [])
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
    @rsync_args_compat.push "--recursive"
    @verbose_args = %w(--verbose --progress --human-readable)
    @exclude = [ '/.Trash-1000/', '/lost+found', '*/*Cache*/*', '*/*cache*/*']
    @skipped_files = []
    @show_backup_list = false
    @show_inaccessable = true
  end
  
################################################################################
# general helper methods
  
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
  def exit
    puts
    warn "Backup aborted!"
    Process.exit!
  end
  
  # output a list in a standard format
  def output_list(heading = "", list = [])
     info heading
     list.each do |l|
       info "  => #{l}"
     end
  end

  # read keyboard response, return true if response is y,Y or '' (return)
  # return true if not verbose
  def proceed?
    return true unless @verbose
    print "(II) Proceed?  (<y>/n): "
    response = gets.chomp.gsub("\\n","")
    response.downcase == 'y' || response == ''
    rescue Exception => e
      exit
  end
  
  # return a string containing the filename of this class
  def class_name
    File.expand_path caller[0].split(":")[0]
  end
  
################################################################################
# rsync helpers
  
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
    result = @rsync_args
    result.concat @verbose_args if @verbose
    args_str = ""
    result.each do |a|
      args_str = "#{args_str} #{a}"
    end
    args_str
  end
  
  # build the command to run
  def command
    "#{rsync} #{args} #{exclude_list} #{backup_list} '#{backup_dest}'"
  end
  
  # does a test backup succeed?
  # test:  perform a small test backup (1 file - this backup script)
  # return true if the source and destination file is the same file size
  def test_succeeds?
    info "Performing test backup... (this script)"
    do_backup "#{rsync} #{args} #{class_name} #{backup_dest}", false
    destination = File.join(backup_dest, File.basename(class_name))
    destination.size == class_name.size
  end
################################################################################
# helper methods for the list of files and directories to be backed up
  
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
  
  # is there at least 1 directory or file to backup?
  def backup_list?
    backup_list != nil
  end
  
  # build exclude list...
  def exclude_list
    result = nil
    @exclude.each do |ex|
      result = "#{result} --exclude '#{ex}'"
    end
    result
  end
  
  # list inaccessible files or directories (but not subdirectories)
  def show_inaccessible
    msg = "#{@skipped_files.size} files/directories inaccessible.  " + \
        "Try running as root.  Inaccessable:"
    warn msg
    @skipped_files.each do |sk|
      warn "  => #{sk}"
    end
  end
  
################################################################################
# helper methods for the backup destination
  
  # search for the first backup destination
  def backup_dest
    @backup_dests.each do |dest|
      path = File.expand_path dest
      return path if File.readable? path # found!
    end
    nil
  end
  
  # is there a valid backup destination path?
  def backup_dest?
    backup_dest != nil
  end
  
########################################################################### MAIN
# main logic
  
  # start backup if everything is OK
  def start
    return unless rsync? and backup_list? and backup_dest?
    # perform a small test backup (this file - FAT32 detection/workaround)
    compatibility_fix unless test_succeeds?
    output_list "Backup list:", @backup_paths if @show_backup_list
    show_inaccessible if @show_inaccessable
    info "Backing up to: '#{backup_dest}'"
    info "About to run command: #{command}"
    return unless proceed?
    info "Proceeding with backup, please wait..."
    start_time = Time.new
    do_backup
    duration = Time.new.to_i - start_time.to_i
    hrs = duration / 3600
    min = (duration / 60) % 60
    sec = duration % 60
    duration_s = "%02d:%02d:%02d" % [hrs, min, sec]
    puts ''
    info "Backup complete!  Time elapsed: #{duration_s}"
  end
  
######################################################################## PRIVATE
  private
  
  # perform backup
  def do_backup(args=command, verbose=@verbose)
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
    warn "Test backup failed.  Implementing NTFS/FAT32 workaround..."
    @rsync_args.delete "--archive"
    @rsync_args_compat.each do |c|
      @rsync_args.push c unless @rsync_args.include? c
    end
  end
end
