#!/usr/bin/env ruby

require 'etc'
require_relative 'proc_status'
require_relative 'proc_meminfo'

module Procfs
	class Scanner

		def self.init(opts={:logger=>logger})
			@@logger = opts[:logger]
		end

		attr_reader :pids, :meminfo, :root
		def initialize
			# array of pids for all processes scanned
			@pids = []
			# array of top level process status objects
			@root = []
			@pid_status = {}
			@meminfo = Procfs::Meminfo.new
			@@logger.debug @meminfo.inspect
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

		##
		# @param [Integer] uid uid to search for in list
		# @param [Array] uids list of uids, or empty list to match all uid
		#
		# @return [Boolean] true if uids is empty or uid is in list
		def uid_in_uids?(uid, uids)
			# an empty uids list is all uids
			uids.empty? || uids.include?(uid)
		end

		def scan(opts={:users=>[]})

			uids = get_uids(opts[:users])

			@pid_status = {}
			Procfs::Common.pid_dirs { |piddir|
				pid=File.basename(piddir)
				dstat = File.lstat(piddir)
				next unless uid_in_uids?(dstat.uid, uids)
				@pids << pid
				pid_status=Procfs::Status.new(pid)
				@pid_status[pid] = pid_status

				# @@logger.debug "%s: pid=%d name=%s ppid=%s vmsize=%s" %
				# 	[
				# 		piddir,
				# 		pid_status.pid,
				# 		pid_status.name,
				# 		pid_status.ppid,
				# 		pid_status.vmsize
				# 	]
			}

			grow_process_tree
		end

		##
		# iterate through all scanned pid_status and setup relationshiops between
		# processes and their children/parents.
		#
		# Also creates and array of top level processes in @root instance variable
		#
		def grow_process_tree
			@pid_status.each_pair { |pid, status|
				next if status.name.eql?("systemd")
				@pid_status.each_pair { |p, s|
					next if p == pid
					status.add_child(s)
				}
			}

			@pid_status.each_pair { |pid, status|
				@root << status if status.parent.nil? || status.ppid == 1
			}
		end

		##
		# print process tree for each top level process sorted by total rss
		#
		def print_process_tree()
			@root.sort_by { |root_status|
				root_status.get_rss_total
			}.each { |root_status|
				root_status.print_tree
			}
		end

	end
end
