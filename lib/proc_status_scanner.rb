#!/usr/bin/env ruby

require 'etc'
require_relative 'proc_status'

class ProcStatusScanner

	##
	# Get a list of uids for the list of users
	#
	# @param [Array] users list of users or empty for current user, or all users
	# for user root
	def get_uids(users)
		if users.empty?
		end
		users.each { |user|
			uid = get_userid(user)
			
		}
	end

	def get_pids(opts={:users=>[]})

		 uid = get_useruid(user)
		 pids=Dir.glob("/proc/[0-9]*")

		 pids.each { |pid|
			  unless uid.nil?
					dstat=lstat(pid)
					next if dstat.nil? || dstat.uid != uid
			  end
			  pid_cmdline=File.join(pid, "cmdline")
			  cmdline=File.read(pid_cmdline).strip
			  # cmdline and options are split by EOS character
			  chunks=cmdline.split(/\0/)
			  chunks.each { |chunk|
					next if chunk[regexp].nil?
					ipid = File.basename(pid).to_i
					if ipid == Process.pid
						 $log.debug "Don't kill yourself, ignoring pid=#{ipid}"
						 next
					end
					$log.debug "#{uid}.#{pid}>> [#{process_name} in #{chunks.inspect}]"
					ipids << ipid
					return ipids if oneshot
			  }
		 }
		 ipids
	end

end
