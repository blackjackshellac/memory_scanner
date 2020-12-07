
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

			@logger.debug "data=#{@data.inspect}"

			# convert timestamps to Time objects
			@data.keys.each { |ts|
				@data[Time.parse(ts)] = @data.delete ts
			}
			@data.map { |ts, record|
				record[MEMINFO] = MemInfoRecord.json_create(record[MEMINFO]) if record.key?(MEMINFO)
				statuses = JsonStatusRecords.new(ts)
				statuses.load(record[STATUSES])
				record[STATUSES] = statuses unless statuses.empty?
			}

		rescue => e
			e.backtrace.each { |line|
				@logger.error line
			}
			@logger.die "#{e.class}: #{e.message}"
		end

		def save(pretty: false)
			@logger.info "Saving json #{@jsonf}"
			File.open(@jsonf, "w") { |fd|
				fd.puts (pretty ? JSON.pretty_generate(self) : self.to_json)
			}
		end

		def record(ts:, meminfo:, statuses:)
			tss=ts.to_s
			@logger.debug "Recording #{meminfo.inspect} at #{tss}"
			@data[tss]={}
			@data[tss][MEMINFO]=MemInfoRecord.create(meminfo)
			@data[tss][STATUSES]=JsonStatusRecords.new(ts)
			statuses.each { |status|
				@data[tss][STATUSES] << StatusRecord.create(status)
			}
		end

		def to_json(*a)
			# hash.each_with_object([]) { |(k, v), array| array << k }
			hash={}
			@data.each_with_object(hash) { |(ts, record), h|
				tss=ts.to_s
				h[tss] = {}
				@logger.debug "MEMINFO record="+record[MEMINFO].inspect
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
			ts = Time.parse(ts) if ts.class == String
			raise ArgumentError, "ts is not a Time or String variable" unless ts.class == Time
			@ts = ts
		end

		def load(statuses)
			return if statuses.nil?
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
