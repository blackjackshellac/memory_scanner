
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
			#puts data.inspect
			@data = data
			# data[:records].each { |dr|
			# 	record = DataRecord.new(dr)
			# 	@data[:records] << record
			# }
		rescue Errno::ENOENT => e

		end

		def save
			@logger.info "Saving json #{@jsonf}"
			File.open(@jsonf, "w") { |fd|
				puts @data.inspect
				fd.puts JSON.pretty_generate(@data)
			}
		end

		def record(ts:, meminfo:)
			@data[:records] << DataRecord.meminfo(ts, meminfo)
		end
	end

	class DataRecord
		KEYS=[ :ts, :total_mem, :free_mem, :avail_mem, :total_swap, :free_swap ]

		def initialize(ts:, total_mem:, free_mem:, avail_mem:, total_swap: , free_swap:)
			@ts = ts
			@total_mem = total_mem
			@free_mem = free_mem
			@avail_mem = avail_mem
			@total_swap = total_swap
			@free_swap = free_swap
		end

		def self.meminfo(ts, meminfo)
			DataRecord.new(
				ts: ts,
				total_mem: meminfo.memtotal,
				free_mem: meminfo.memfree,
				avail_mem: meminfo.memavailable,
				total_swap: meminfo.swaptotal,
				free_swap: meminfo.swapfree
			)
		end

		def to_json(*a)
			{
				ts: @ts.to_s,
				total_mem: @total_mem,
				free_mem: @free_mem,
				avail_mem: @avail_mem,
				total_swap: @total_swap,
				free_swap: @free_swap
			}.to_json(*a)
		end

		def self.json_create(dr)
			puts dr.inspect
		end
	end
end
