
module Procfs
	class Records
		def initialize(jsonf:, logger:)
			@data = {
				meminfo: [], # Array of type MemInfoRecord
				psinfo: []
			}
			@jsonf = jsonf
			@json = nil
			@logger = logger
		end

		def load
			return unless File.exist?(@jsonf)
			@logger.info "Loading json #{@jsonf}"
			@json = File.read(@jsonf)
			@data = JSON.parse(@json, symbolize_names: true)
			@data[:meminfo] ||= []
			@data[:psinfo] ||= []
			@data[:meminfo].map.with_index { |mi, idx|
				@data[:meminfo][idx] = MemInfoRecord.json_create(mi)
			}
		rescue Errno::ENOENT => e

		end

		def save(pretty: false)
			@logger.info "Saving json #{@jsonf}"
			File.open(@jsonf, "w") { |fd|
				fd.puts (pretty ? JSON.pretty_generate(self) : self.to_json)
			}
		end

		def record(ts:, meminfo:)
			@data[:meminfo] << MemInfoRecord.meminfo(ts, meminfo)
		end

		def to_json(*a)
			{
				meminfo: @data[:meminfo],
				psinfo: @data[:psinfo]
			}.to_json(*a)
		end

		# def extract(meminfo: true, psinfo: false, key)
		# 	@data[:meminfo].each_with_object([]) { |meminfo_record, values|
		# 		next unless meminfo_record.key?(key.to_sym)
		# 	}
		# end
	end

end
