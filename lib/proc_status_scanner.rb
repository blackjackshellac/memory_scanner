#!/usr/bin/env ruby

require 'etc'
require_relative 'proc_status'

module Procfs
	class Scanner

		def self.init(opts={:logger=>logger})
			@@logger = opts[:logger]
		end

		attr_reader :pids
		def initialize
			@pids = []
			get_pids({:users=>[]})

		end

		##
		# Get a list of uids for the list of users
		#
		# @param [Array] users list of users or empty for current user, or all users
		# for user root
		def get_uids(users)
			if users.nil? || users.empty?
				users ||= []
				curuser = Etc.getlogin
				users << curuser unless curuser.eql?("root")
			end
			uids = []
			users.each { |user|
				uid = Etc.getpwnam(user).uid
				uids << uid.to_i

			}
			uids
		end

		def get_pids(opts={:users=>[]})

			uids = get_uids(opts[:users])
			piddirs=Dir.glob("/proc/[0-9]*")

			@pid_status = {}
			piddirs.each { |piddir|
				pid=File.basename(piddir)
				@pids << pid
				@pid_status[pid]=Procfs::Status.new(pid)

				@@logger.debug "pid=#{pid} status=#{@pid_status[pid].fields[:vmdata]}"
			}

		end

	end
end
