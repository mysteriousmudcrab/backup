#!/usr/bin/ruby
require 'backup.rb'

# Basic usage:
#d = Backup.new true, '/usr/bin/rsync', true, ['~/Documents/'], ['/back up/']
#               verbose?,               exclude movies?,        destinations
#                     rsync path,             backup paths,
# (no need to call d.start if enough parameters specified)

# Backup to cloud example:
#c = Backup.new true, 'usr/bin/rsync', true, ['~/small/'], ['~/Ubuntu One/']

b = Backup.new # use defaults

# the files and/or directories to back up
b.backup_paths = [ 
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

# where files and directories are backed up to.
# if multiple locations specified, the first existing location will be used
# (e.g., if 1st removable media is not present, 2nd is used, etc.)
b.destination_paths = [
  '/media/landfill/Andy/backup/',
  '/windows/backup/',
]

# things we don't want backed up!
b.exclude_list = [
  '/.Trash-1000/',
  '/lost+found',
  '*/*Cache*/*',
  '*/*cache*/*',
]

b.start # start the backup!
