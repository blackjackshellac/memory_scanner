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
		attr_reader :logger
		def initialize
			@logger = Logger.create(STDERR, Logger::INFO)
			Procfs::Scanner.init({:logger=>@logger})
		end

		def parse_clargs
			optparser=OptionParser.new { |opts|
				opts.banner = "#{MERB} [options]\n"

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
