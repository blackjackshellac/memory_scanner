#
#

require 'etc'

require_relative 'proc_common'
require_relative 'numeric_ext'

module Procfs
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

	# Uid and Gid fields
	# Uid: real UID, effective UID, saved set UID, and file system UID
	# Gid: real GID, effective GID, saved set GID, and file system GID
	class Status
		attr_reader :pid, :status, :fields, :children
		attr_reader :name, :ppid, :vmsize, :vmrss, :vmswap
		attr_reader :rss_total, :ids, :uid, :gid, :username, :group
		attr_accessor :parent
		def initialize(pid)
			@pid = pid
			@status=File.read(File.join("/proc", @pid, "status"))
			@fields = Common.parse_name_value(@status)
			@children = []
			@rss_total = nil
			@parent = nil
			%w/Name PPid VmSize VmRss VmSwap/.each { |field|
				fsym = Common.symbolize(field)
				fval = @fields[fsym]
				instance_variable_set("@#{fsym}", @fields[fsym])
			}
			@ids = {}
			%w/Uid Gid/.each { |field|
				fsym = Common.symbolize(field)
				fval = @fields[fsym]
				vals = fval.split(/\s+/, 4)
				@ids[fsym]||={}
				%w/real effective saved_set fiile_system/.each_with_index { |value, i|
					@ids[fsym][value.to_sym] = vals[i].to_i
				}
			}
			@uid = @ids[:uid][:real]||-1
			@username = @uid == -1 ? "unknown uid" : Etc.getpwuid(@uid).name
			@gid = @ids[:gid][:real]||-1
			@group = @gid == -1 ? "unknown gid" : Etc.getgrgid(@gid).name
		end

		def add_child(status)
			return false unless status.ppid == @pid
			@children << status unless @children.include?(status)
			status.parent = @pid
			#puts "Added child: %s:%d children=[%s]" % [ @name, @pid, @children.join(", ") ]
			true
		end

		##
		# get the total amount of memory for this process and all of its children
		#
		# @return [String] total size of memory including children
		def get_total_memory(vmvalue)
			total = instance_variable_get("@#{vmvalue}").to_i
			@children.each { |child_status|
				total += child_status.get_total_memory(vmvalue)
			}
			total
		end

		def get_rss_total
			@rss_total = get_total_memory("vmrss") if @rss_total.nil?
			@rss_total
		end

		def summary(tabs)
			@rss_total = get_rss_total
			return "%s+ %s:%d> %s:%d TotalRss=[%s] VmSize=[%s] VmRss=[%s]%s" % [ tabs, @name, @pid, @username, @uid,
			 	@rss_total.to_bibyte, @vmsize.to_bibyte, @vmrss.to_bibyte, vmswap.to_i <= 0 ? "" : " VmSwap=[#{@vmswap.to_bibyte}]"]
		end

		##
		# print summary of process, and recursively for children, sorted by total
		# rss memory usage
		#
		def print_tree(indent=0)
			puts summary("\t"*indent)
			@children.sort_by { |child_status|
				child_status.get_rss_total
			}.each { |child_status|
				# recursively print trees for child statuses
				child_status.print_tree(indent+1)
			}
		end
	end
end
