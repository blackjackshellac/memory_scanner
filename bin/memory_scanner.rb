#!/usr/bin/env ruby
#
#

require_relative '../lib/logger'
require_relative '../lib/proc_status_scanner'
require_relative '../lib/proc_json_records'
require_relative '../lib/emailer'
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
		HOST=%x/hostname -s/.strip
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
			@ts = now
			@users = []
			@monitor = nil
			@process_tree = true
			@meminfo_summary = true
			@record=""
			@scanid=@ts.strftime("#{ME}_%Y%m%d")
			@data_records = nil
			@email = ENV['NOTIFY_EMAIL']||nil
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

				opts.on('-e', '--email EMAIL', String, "Notification email, can be set with NOTIFY_EMAIL env var") { |email|
					@email = email
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
			@logger.debug "Saving data_records"
			statuses = @ps.filter_statuses(percent_mem: 5)
			@data_records.record(ts: @ts, meminfo: @ps.meminfo, statuses: statuses)
			@data_records.save(pretty: pretty)
			@logger.debug "Done saving data_records"
		end

		def monitor_wait(save_thread)
			return false if @monitor.nil?
			@logger.debug "Sleeping #{@monitor} seconds"
			sleep @monitor
			if save_thread.alive?
				@logger.info "Waiting for save thread"
				save_thread.join
			end
			true
		end

		def thread_save(pretty: false)
			# When set to true, if this thr is aborted by an exception,
			# the raised exception will be re-raised in the main thread.
			save_thread = nil
			Thread.abort_on_exception = true
			Thread.handle_interrupt(Interrupt => :never) {
				save_thread = Thread.new {
					save_data_records(pretty: pretty)
				}
			}
			save_thread
		end

		def scan
			@ts = now
			@logger.debug "Scanning system at #{@ts}"
			@ps = Procfs::Scanner.new(logger: @logger)
			@ps.proc_scan(@users)
		end

		def notify(addr:)
			return if addr.nil?

			@logger.info "Notify #{addr}"
			emailer=Notify::Emailer.new
			#emailer.setup(to: addr, subject:"foo")
			emailer.to = addr
			emailer.from = addr
			emailer.subject = "#{HOST}: #{ME} report"
			#emailer.attach("/var/tmp/memory_scanner/steeve/memory_scanner_20201209.json")

			processes = StringIO.new
			meminfo = StringIO.new
			@ps.meminfo.summary(stream: meminfo)
			@ps.print_process_tree(stream: processes, descending: true)

			body=<<~BODY
				#{ME} #{@ts.to_s}

				#{meminfo.string}
				#{"+"*80}
				#{processes.string}
			BODY

			emailer.text_part {
				body "#{body}"
			}
			emailer.html_part {
				content_type 'text/html; charset=UTF-8'
	    		body "<pre>#{body}</pre>"
			}
			emailer.send

		end

		def run
			save_thread = nil
			begin
				load_data_records

				loop {
					scan()

					save_thread = thread_save(pretty: true)

					notify(addr: @email)

					break unless monitor_wait(save_thread)
				}

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
			@ps.print_process_tree() if @process_tree
			@ps.meminfo.summary() if @meminfo_summary
		end
	end
end

ms = Memory::ScannerMain.new
ms.parse_clargs
ms.run
ms.summarize
