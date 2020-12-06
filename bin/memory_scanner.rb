#!/usr/bin/env ruby
#
#

require_relative '../lib/logger'
require_relative '../lib/proc_status_scanner'
require_relative '../lib/proc_json_records'
require 'optparse'
require 'fileutils'
require 'etc'

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

		MONITOR_INTERVAL=600

		TMP=File.join("/var/tmp/#{ME}", Etc.getlogin)
		FileUtils.mkdir_p(TMP)

		# @attr_reader [Logger] logger - instance of logger
		attr_reader :logger, :users, :ps
		def initialize
			@logger = Logger.create(STDERR, Logger::INFO)
			@now = now
			@users = []
			@monitor = nil
			@process_tree = true
			@meminfo_summary = true
			@record=""
			@scanid=@now.strftime("#{ME}_%Y%m%d")
			@data_records = nil
			Procfs::Scanner.init({:logger=>@logger})
		end

		def now
			Time.now
		end

		def parse_clargs
			optparser=OptionParser.new { |opts|
				opts.banner = "#{MERB} [options]\n"

				opts.on('-u', '--users USERS', Array, "List of users, default is current user (use :all for all users)") { |users|
					if users.include?(":all")
						@users = [ :all ]
					else
						@users.concat(users)
						@users.uniq!
					end
				}

				opts.on('-m', '--monitor [INTERVAL]', Integer, "") { |interval|
					@monitor = interval.nil? ? MONITOR_INTERVAL : interval
				}

				# TODO it would be better if the data were updated on a running basis,
				# but that would be a lot easier with an SQL database, perhaps this eventually
				# https://github.com/sparklemotion/sqlite3-ruby
				opts.on('-r', '--record [SCANID]', String, "Default scanid is updated daily #{@scanid}") { |scanid|
					@record = setup_record(scanid)
				}

				opts.on('-P', '--[no-]process-tree', "Print the process tree to STDOUT") { |bool|
					@process_tree = bool
				}

				opts.on('-M', '--[no-]meminfo_summary', "Print meminfo summary") { |bool|
					@meminfo_summary = bool
				}

				opts.on('-q', '--quiet', "Quiet") {
					@meminfo_summary = false
					@process_tree = false
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

			# if monitoring make sure record is turned on
			@record = setup_record(@scanid) if @monitor && @record.empty?

			@data_records = Procfs::JsonRecords.new(jsonf: @record, logger: @logger) unless @record.empty?

		rescue OptionParser::InvalidOption => e
			@logger.die "#{e.class}: #{e.message}"
		end

		def setup_record(scanid)
			@scanid = scanid unless scanid.nil?
			record = File.join(TMP, @scanid+".json")
			@logger.info "Recording to #{record}"
			record
		end

		def load_data_records
			return if @data_records.nil?
			@data_records.load
		end

		def save_data_records(pretty: true)
			return if @data_records.nil?
			@data_records.record(ts: @now, meminfo: @ps.meminfo, pid_status: @ps.pid_status)
			@data_records.save(pretty: pretty)
		end

		def scan
			# When set to true, if this thr is aborted by an exception,
			# the raised exception will be re-raised in the main thread.
			Thread.abort_on_exception = true
			save_thread = nil
			begin
				load_data_records

				loop do
					@now = now
					@logger.debug "Scanning system at #{@now}"
					@ps = Procfs::Scanner.new
					@ps.scan(users: @users)
					Thread.handle_interrupt(Interrupt => :never) {
						save_thread = Thread.new {
							save_data_records(pretty: true)
						}
					}
					break if @monitor.nil?
					@logger.debug "Sleeping #{@monitor} seconds"
					sleep @monitor
					if save_thread.alive?
						@logger.info "Waiting for save thread"
						save_thread.join
					end
				end	# loop do
			rescue Interrupt => e
				@logger.warn "Caught interrupt"
			rescue => e
				@logger.error "memory scan failed: #{e.message}"
				puts e.backtrace.join("\n")
				exit 1
			ensure
				unless save_thread.nil?
					save_thread.join if save_thread.alive?
				end
			end
		end

		def summarize
			@ps.print_process_tree(STDOUT) if @process_tree
			@ps.meminfo.summary(STDOUT) if @meminfo_summary
		end
	end
end

ms = Memory::ScannerMain.new
ms.parse_clargs
ms.scan
ms.summarize
