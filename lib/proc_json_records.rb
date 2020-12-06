
require 'json'

module Procfs
	class JsonRecords

		MEMINFO="mi".freeze
		STATUSES="sts".freeze

		def initialize(jsonf:, logger:)
			#
			# @data = {
			# 	"timestamp": {
			# 		meminfo: meminfo_val,
			# 		psinfo: psinfo_val
			# 	},
			# 	"next timestamp": {
			#
			# 	}
			# 	...
			# }
			@data = {}
			@jsonf = jsonf
			@json = nil
			@logger = logger
		end

		def load
			return unless File.exist?(@jsonf)
			@logger.info "Loading json #{@jsonf}"
			@json = File.read(@jsonf)
			@data = JSON.parse(@json)

			puts "data=#{@data.inspect}"

			# convert timestamps to Time objects
			@data.keys.each { |ts|
				@data[Time.parse(ts)] = @data.delete ts
			}
			@data.map { |ts, record|
				record[MEMINFO] = MemInfoRecord.json_create(ts, record[MEMINFO]) if record.key?(MEMINFO)
				statuses = JsonStatusRecords.new(ts)
				if record.key?(STATUSES)
					statuses.load(record[STATUSES])
				end
				record[STATUSES] = statuses
			}

		rescue Errno::ENOENT => e

		end

		def save(pretty: false)
			@logger.info "Saving json #{@jsonf}"
			File.open(@jsonf, "w") { |fd|
				fd.puts (pretty ? JSON.pretty_generate(self) : self.to_json)
			}
		end

		def record(ts:, meminfo:, pid_status:)
			tss=ts.to_s
			@logger.debug "Recording #{meminfo.inspect} at #{tss}"
			@data[tss]={}
			@data[tss][MEMINFO]=MemInfoRecord.create(ts, meminfo)
			@data[tss][STATUSES]=JsonStatusRecords.new(ts)
			pid_status.each_pair { |pid, status|
				@data[tss][STATUSES] << StatusRecord.create(status)
			}
		end

		def to_json(*a)
			# hash.each_with_object([]) { |(k, v), array| array << k }
			hash={}
			@data.each_with_object(hash) { |(ts, record), h|
				tss=ts.to_s
				h[tss] = {}
				puts record[MEMINFO].inspect
				h[tss][MEMINFO]=record[MEMINFO] if record.key?(MEMINFO)
				h[tss][STATUSES]=record[STATUSES] if record.key?(STATUSES)
			}
			hash.to_json(*a)
		end

		# def extract(meminfo: true, psinfo: false, key)
		# 	@data[:meminfo].each_with_object([]) { |meminfo_record, values|
		# 		next unless meminfo_record.key?(key.to_sym)
		# 	}
		# end
	end

	class JsonStatusRecords < Array
		attr_reader :ts
		def initialize(ts)
			@ts = ts
		end

		def load(statuses)
			statuses.each { |status|
				status.keys.each { |key|
					# convert status keys to symbols
					status[key.to_sym] = status.delete key
				}
				self << StatusRecord.new(status)
			}
			self
		end
	end
end
