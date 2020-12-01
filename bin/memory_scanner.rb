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
module Memory
	include Procfs

	class ScannerMain
		## Process name with extension
      MERB=File.basename($0)
      ## Process name without .rb extension
      ME=File.basename($0, ".rb")
      # Directory where the script lives, resolves symlinks
      MD=File.expand_path(File.dirname(File.realpath($0)))

		# @attr_reader [Logger] logger - instance of logger
		attr_reader :logger, :users
		def initialize
			@logger = Logger.create(STDERR, Logger::INFO)
			@users = []
			@process_tree = false
			@meminfo_summary = true
			Procfs::Scanner.init({:logger=>@logger})
		end

		def parse_clargs
			optparser=OptionParser.new { |opts|
				opts.banner = "#{MERB} [options]\n"

				opts.on('-u', '--users USERS', Array, "List of users, default is all users") { |users|
					@users.concat(users)
					@users.uniq!
				}

				opts.on('-P', '--[no-]process-tree', "Print the process tree to STDOUT") { |bool|
					@process_tree = bool
				}

				opts.on('-M', '--[no-]meminfo_summary', "Print meminfo summary") { |bool|
					@meminfo_summary = bool
				}

				opts.on('-D', '--debug', "Enable debugging output") {
					@logger.level = Logger::DEBUG
				}

				opts.on('-h', '--help', "Help") {
					$stdout.puts ""
					$stdout.puts opts
					exit 0
				}

			}
			optparser.parse!

		end

		def scan
			@logger.debug "Scanning system at #{Time.now}"
			ps = Procfs::Scanner.new
			ps.scan(:users=>@users)

			ps.print_process_tree(STDOUT) if @process_tree
			ps.meminfo.summary(STDOUT) if @meminfo_summary

			return 0
		rescue => e
			@logger.error "memory scan failed: #{e.message}"
			puts e.backtrace.join("\n")
			return 1
		end
	end
end

ms = Memory::ScannerMain.new
ms.parse_clargs
ev = ms.scan
exit ev
