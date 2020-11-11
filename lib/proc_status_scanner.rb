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
		end

		def getuseruid(user)
			begin
				return Etc.getpwnam(user).uid
			rescue => e
				@@logger.warn e.to_s
			end
			nil
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
					uid = getuseruid(user)
					uids << uid unless uid.nil?
			}
			uids
		end

		def get_pids(opts={:users=>[]})

			uids = get_uids(opts[:users])
			piddirs=Dir.glob("/proc/[0-9]*")

			@pid_status = {}
			piddirs.each { |piddir|
				pid=File.basename(piddir)
				dstat = File.lstat(piddir)
				next if !uids.empty? && !uids.include?(dstat.uid)
				@pids << pid
				pid_status=Procfs::Status.new(pid)
				@pid_status[pid] = pid_status

				@@logger.debug "pid=#{pid} uid=#{pid_status.fields[:uid]} vmdata=#{pid_status.fields[:vmdata]}"
			}

		end

	end
end
