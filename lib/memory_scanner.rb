#!/usr/bin/env ruby
#
#

require 'logger'
require 'optparse'

class Logger
	DATE_FORMAT="%Y-%m-%d %H:%M:%S"

	##
	# Send an error message
	#
	# @param [String] msg error message
	#
	def err(msg)
		error(msg)
	end

	##
	# Print an error message and exit immediately with exit errno 1
	#
	# @param [String] msg error message
	# @param [Integer] errno optional exit errno value, default is 1
	#
	def die(msg, errno=1)
		error(msg)
		exit errno
	end

	##
	# Create a logger with the given stream or file
	#
	# @overload create(filename, level)
	#   Create a file logger
	#   @param [String] stream filename
	#   @param [Integer] level log level
	# @overload create(iostream, level)
	#   @param [IO] stream STDOUT or STDERR or other io stream
	#   @param [Integer] level log level
	#
	# @return [Logger] the logger object
	#
	def self.create(stream, level=Logger::INFO)
		log = Logger.new(stream)
		log.level = level
		log.datetime_format = DATE_FORMAT
		log.formatter = proc do |severity, datetime, progname, msg|
			"#{severity} #{datetime}: #{msg}\n"
		end
		log
	end

end

##
#
# Scan linux memory for overuse and other notable conditions
#
# @author blackjackshellac
#
class MemoryScanner

	# @attr_reader [Logger] logger - instance of logger
	attr_reader :logger
	def initialize
		@logger = Logger.create(STDERR, Logger::INFO)
	end

	# $ cd /proc/[pid]
	# $ cat status
	# Name:	Web Content
	# Umask:	0022
	# State:	S (sleeping)
	# Tgid:	377820
	# Ngid:	0
	# Pid:	377820
	# PPid:	377642
	# TracerPid:	0
	# Uid:	1201	1201	1201	1201
	# Gid:	1201	1201	1201	1201
	# FDSize:	128
	# Groups:	10 494 496 497 501 1201 1205
	# NStgid:	377820
	# NSpid:	377820
	# NSpgid:	3035
	# NSsid:	3035
	# VmPeak:	 3425508 kB
	# VmSize:	 3321700 kB
	# VmLck:	       0 kB
	# VmPin:	       0 kB
	# VmHWM:	  754624 kB
	# VmRSS:	  452668 kB
	# RssAnon:	  342052 kB
	# RssFile:	   95612 kB
	# RssShmem:	   15004 kB
	# VmData:	  617768 kB
	# VmStk:	     252 kB
	# VmExe:	     400 kB
	# VmLib:	  139648 kB
	# VmPTE:	    3048 kB
	# VmSwap:	       0 kB

	def scan
		return 0
	rescue => e
		@logger.error "memory scan failed: #{e.message}"
		puts e.backtrace.join("\n")
		return 1
	end
end

ms = MemoryScanner.new
ev = ms.scan
exit ev
