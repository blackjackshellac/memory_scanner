#!/usr/bin/env ruby
#
#

require_relative '../lib/logger'
require_relative '../lib/proc_status_scanner'
require 'optparse'

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
