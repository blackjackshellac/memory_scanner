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

		DEF_CONFIG = File.join(MD, ME+".json")

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
			@record=false
			@scanid=@ts.strftime("#{ME}_%Y%m%d")
			@data_records = nil
			@email = ENV['NOTIFY_EMAIL']||nil
			@threshold_memhog = 33 # notify when a process uses more than 40% of total ram

			# first notificaiton will always go out
			@last_notification = Time.at(0)
			@wait_notify = 15*60	# 15 minutes

			@config = nil
			@config_hash = {}
		end

		def now
			Time.now
		end

		def load_config
			return if @config.nil?

			@logger.info "Loading #{@config}"
			json = File.read(@config)
			cfg = JSON.parse(json, symbolize_names: true)
			cfg.each_pair { |key,val|
				process_arg(key, val)
			}
		rescue Errno::ENOENT => e
			@logger.warn "Failed to load config #{@config}, one will be created with the given options"
		rescue => e
			@logger.die "#{e.class}: Failed to load config #{@config} [#{e.message}]"
		end

		def save_config
			return if @config.nil?
			File.open(@config, "w+") { |fd|
				@logger.info "Saving config #{@config}"
				fd.puts(JSON.pretty_generate(@config_hash))
			}
		rescue => e
			@logger.die "Failed to save config #{@config}"
		end

		def process_arg(key, val=nil)
			case key.to_sym
			when :users
				if val.include?(":all")
					@users = [ :all ]
				else
					@users.concat(val)
					@users.uniq!
				end
				val = @users
			when :monitor
				@monitor = val.nil? ? MONITOR_INTERVAL : val
				val = @monitor
			when :email
				@email = val
			when :process_tree
				@process_tree = val
			when :meminfo_summary
				@meminfo_summary = val
			when :quiet
				process_arg(:process_tree, false)
				process_arg(:meminfo_summary, false)
			when :debug
				@logger.level = Logger::DEBUG
				val = true
			when :scanid
				@scanid = val unless val.nil?
				val = @scanid
			when :record
				@record = val
			else
				@logger.error "Unknown configuration #{key.to_s}"
			end
			@config_hash[key] = val.nil? ? true : val
		end

		def parse_clargs
			optparser=OptionParser.new { |opts|
				opts.banner = "#{MERB} [options]\n"

				opts.on('-c', '--config [CONFIG]', String, "Load config from json") { |config|
					@config = config.nil? ? DEF_CONFIG : config
				}

				opts.on('-u', '--users USERS', Array, "List of users, default is current user (use :all for all users)") { |users|
					process_arg(:users, users)
				}

				opts.on('-m', '--monitor [INTERVAL]', Integer, "Run a scan periocially, def is #{MONITOR_INTERVAL} secs") { |interval|
					process_arg(:monitor, interval)
				}

				opts.on('-e', '--email EMAIL', String, "Notification email, can be set with NOTIFY_EMAIL env var") { |email|
					process_arg(:email, email)
				}

				# TODO it would be better if the data were updated on a running basis,
				# but that would be a lot easier with an SQL database, perhaps this eventually
				# https://github.com/sparklemotion/sqlite3-ruby
				opts.on('-r', '--record [SCANID]', String, "Default scanid is updated daily #{@scanid}") { |scanid|
					process_arg(:record, true)
					process_arg(:scanid, scanid)
				}

				opts.on('-P', '--[no-]process-tree', "Print the process tree to STDOUT") { |bool|
					proess_arg(:process_tree, bool)
				}

				opts.on('-M', '--[no-]meminfo_summary', "Print meminfo summary") { |bool|
					process_arg(:meminfo_summary, true)
				}

				opts.on('-q', '--quiet', "Quiet") {
					process_arg(:quiet)
				}

				opts.on('-D', '--debug', "Enable debugging output") {
					process_arg(:debug)
				}

				opts.on('-h', '--help', "Help") {
					$stdout.puts ""
					$stdout.puts opts
					exit 0
				}

			}
			optparser.parse!

			load_config
			save_config

			# if monitoring make sure record is turned on
			@record = setup_record(@scanid) if @monitor || @record

			@data_records = Procfs::JsonRecords.new(jsonf: @record, logger: @logger) unless @record == false || @record.empty?

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

		def add_section(title:"", section:nil, sep:"+"*132)
			title="\n#{title}\n" unless title.empty?
			(section.nil? || section.empty?) ? "" : "%s%s\n%s\n" % [ title, section, sep ]
		end

		def do_notify(urgent)
			notify = (urgent || (@last_notification + @wait_notify) > @ts)
			@last_notification = @ts if notify
			notify
		end

		##
		# sections = Hash with keys title, section
		def notify(to:, from: nil, sections:{}, urgent: false)
			return if to.nil?
			return unless do_notify(urgent)

			# delete sections that are nil or empty
			sections.delete_if { |k, section| section.nil? || section.empty? }
			# don't notify if there are no sections to report
			return if sections.empty?

			@logger.info "Notify #{to}"
			emailer=Notify::Emailer.new
			#emailer.setup(to: to, subject:"foo")
			emailer.to = to
			emailer.from = from.nil? ? to : from
			emailer.subject = "#{HOST}: #{ME} report"
			#emailer.attach("/var/tmp/memory_scanner/steeve/memory_scanner_20201209.json")

			processes = StringIO.new
			meminfo = StringIO.new
			@ps.meminfo.summary(stream: meminfo)
			@ps.print_process_tree(stream: processes, descending: true)

			sep="+"*132

			body="#{ME} Report -  #{@ts.to_s}\n\n"

			sections.each_pair { |title,section|
				body += add_section(title: title, section:section)
			}

			body += add_section(title: "Summary /proc/meminfo", section:meminfo.string)
			body += add_section(title: "Summary /proc/*/status", section:processes.string)

			emailer.text_part {
				body "#{body}"
			}
			emailer.html_part {
				content_type 'text/html; charset=UTF-8'
				body "<pre style='font-family: \"Courier New\", Courier, mono; font-size: 12px;'>#{body}</pre>"
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

					memhogs = @ps.find_memhogs(highmem: @threshold_memhog)
					swaphogs = nil

					sections={
						"Mem hogs report" => memhogs,
						"Swap hogs report" => swaphogs
					}
					notify(to: @email, sections: sections)

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
