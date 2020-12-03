
module Procfs
	class Records
		def initialize(jsonf:, logger:)
			@data = {
				records: [] # Array of type DataRecord
			}
			@jsonf = jsonf
			@json = nil
			@logger = logger
		end

		def load
			return unless File.exist?(@jsonf)
			@logger.info "Loading json #{@jsonf}"
			@json = File.read(@jsonf)
			data = JSON.parse(@json, symbolize_names: true)
			puts data.inspect
			data[:records].each { |dr|
				record = DataRecord.new(dr)
				@data[:records] << record
			}
		rescue Errno::ENOENT => e

		end

		def save
			@logger.info "Saving json #{@jsonf}"
			File.open(@jsonf, "w") { |fd|
				puts @data.inspect
				fd.puts JSON.pretty_generate(@data)
			}
		end

		def record(record)
			@data[:records] << record
		end
	end

	class DataRecord
		KEYS=[ :ts, :total_mem, :free_mem, :avail_mem, :total_swap, :free_swap ]

		def initialize(ts:, total_mem:, free_mem:, avail_mem:, total_swap: , free_swap:)
		end

		#def to_json(*)
		#end
	end
end
