
require_relative 'proc_common'

module Procfs
	# $ cd /proc/[pid]
	# $ cat meminfo
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

	class Meminfo
		attr_reader :meminfo, :fields
		def initialize
			@meminfo=File.read(File.join("/proc", "meminfo"))
			@fields = Procfs::Common.parse_name_value(@meminfo)
		end
	end
end
