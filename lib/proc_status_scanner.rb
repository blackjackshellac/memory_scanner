#!/usr/bin/env ruby

require 'etc'
require_relative 'proc_status'
require_relative 'proc_meminfo'

module Procfs
	class Scanner

		attr_reader :pids, :meminfo, :root, :pid_status
		def initialize(logger:)
			# array of pids for all processes scanned
			@pids = []
			# array of top level process status objects
			@root = []
			@pid_status = {}
			@meminfo = Procfs::Meminfo.new
			@logger = logger
		end

		def getuseruid(user)
			begin
				return Etc.getpwnam(user).uid
			rescue => e
				@logger.warn "#{e.class}: #{e.to_s}"
			end
			nil
		end

		##
		# Get a list of uids for the list of users
		#
		# @param [Array] users list of users or empty for current user, or all users
		# for user root
		def get_uids(users)
			#puts "users=#{users.inspect}"
			if users.nil? || users.empty?
				users ||= []
				curuser = Etc.getlogin
				users << curuser unless curuser.eql?("root")
			elsif users.include?(:all)
				return []
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

		def proc_scan(users)

			uids = get_uids(users)

			@pid_status = {}
			Procfs::Common.pid_dirs { |piddir|
				pid=File.basename(piddir)
				dstat = File.lstat(piddir)
				next unless uid_in_uids?(dstat.uid, uids)
				@pids << pid
				pid_status=Procfs::Status.new(pid)
				@pid_status[pid] = pid_status
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
		def print_process_tree(stream: STDOUT, descending: false)
			@root.sort_by { |root_status|
				tot=root_status.get_rss_total
				descending ? -tot : tot
			}.each { |root_status|
				root_status.print_tree(stream)
			}
		end

		def find_memhogs(highmem: 40)
			memhog=[]
			@pid_status.each_pair { |pid, status|
				memhog << status if status.test_totalrss(highmem: highmem, totalmem: meminfo.memtotal)
			}
			memhog
		end

		##
		# mem_total = 16G
		# percent = 10%
		# processes with rss_total (including children) > 10% of 16G (1.6G)
		def filter_statuses(percent_mem:)
			raise ArgumentError, "Invalid value for percent" if percent_mem < 0 || percent_mem > 100
			max=@meminfo.memtotal*percent_mem/100
			filter=[]
			@pid_status.sort_by { |pid, status|
				-status.get_rss_total
			}.each_with_object(filter) { |pid_status, array|
				# pid_status is a key value array
				status=pid_status[1]
				array << status if status.get_rss_total > max
			}
			@logger.debug "FILTER_STATUSES> "+filter.inspect
			filter
		end

	end
end
