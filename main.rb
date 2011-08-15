#!/usr/bin/ruby
require 'backup.rb'

# Basic usage:
#d = Backup.new true, ['~/Documents/'], ['/back up/']
#               verbose?, backup paths, destinations
#                     
# (no need to call d.start if enough parameters specified)

# Backup to cloud example:
#c = Backup.new true, ['~/small/'], ['~/Ubuntu One/']

# the files and/or folders to back up
backup_paths = [ 
  '~/Documents/',
  '~/Pictures/',
  '~/CQU/',
  '~/Desktop/',
  '~/code/',
  '~/.mozilla/',
  '~/.gimp-2.6',
  '~/.mysql/',
  '/srv/www/',
  '/var/lib/mysql/',
  '/etc/',
]

# where files and folders are backed up to.
# if multiple locations specified, the first existing location will be used
# (e.g., if 1st removable media is not present, 2nd is used, etc.)
backup_dests = [
  '/media/landfill/Andy/backup/',
  '/windows/backup/',
  '/backup/'
]

# things we don't want backed up!  (the below list is included by default.)
#b.exclude = [
#  '/.Trash-1000/',
#  '/lost+found',
#  '*/*Cache*/*',
#  '*/*cache*/*',
#]

b = Backup.new true, backup_paths, backup_dests # start the backup!
