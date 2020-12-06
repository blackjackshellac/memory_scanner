
require_relative 'proc_common'
require_relative 'numeric_ext'
require_relative 'tabular'
require 'time'

module Procfs
	# $ cat /proc/meminfo
	# MemTotal:       16295240 kB
	# MemFree:         6343852 kB
	# MemAvailable:   10214300 kB
	# Buffers:          139844 kB
	# Cached:          4515240 kB
	# SwapCached:            0 kB
	# Active:          2035688 kB
	# Inactive:        6914588 kB
	# Active(anon):       5152 kB
	# Inactive(anon):  4941120 kB
	# Active(file):    2030536 kB
	# Inactive(file):  1973468 kB
	# Unevictable:      422044 kB
	# Mlocked:            6160 kB
	# SwapTotal:      12386296 kB
	# SwapFree:       12386296 kB
	# Dirty:              1156 kB
	# Writeback:             0 kB
	# AnonPages:       4717108 kB
	# Mapped:          1089672 kB
	# Shmem:            684400 kB
	# KReclaimable:     202388 kB
	# Slab:             367344 kB
	# SReclaimable:     202388 kB
	# SUnreclaim:       164956 kB
	# KernelStack:       29600 kB
	# PageTables:        58428 kB
	# NFS_Unstable:          0 kB
	# Bounce:                0 kB
	# WritebackTmp:          0 kB
	# CommitLimit:    20533916 kB
	# Committed_AS:   16305772 kB
	# VmallocTotal:   34359738367 kB
	# VmallocUsed:       68772 kB
	# VmallocChunk:          0 kB
	# Percpu:            10624 kB
	# HardwareCorrupted:     0 kB
	# AnonHugePages:         0 kB
	# ShmemHugePages:        0 kB
	# ShmemPmdMapped:        0 kB
	# FileHugePages:         0 kB
	# FilePmdMapped:         0 kB
	# CmaTotal:              0 kB
	# CmaFree:               0 kB
	# HugePages_Total:       0
	# HugePages_Free:        0
	# HugePages_Rsvd:        0
	# HugePages_Surp:        0
	# Hugepagesize:       2048 kB
	# Hugetlb:               0 kB
	# DirectMap4k:      487980 kB
	# DirectMap2M:     9904128 kB
	# DirectMap1G:     7340032 kB

	class Meminfo
		attr_reader :meminfo, :fields
		attr_reader :memtotal, :memfree, :memavailable, :swaptotal, :swapfree
		attr_reader :mem_percent_free, :mem_percent_used
		attr_reader :swap_percent_free, :swap_percent_used
		def initialize
			@meminfo=File.read(File.join("/proc", "meminfo"))
			@fields = Procfs::Common.parse_name_value(@meminfo)
			%w/MemTotal MemFree MemAvailable SwapTotal SwapFree/.each { |field|
				fsym = Common.symbolize(field)
				fval = @fields[fsym]
				instance_variable_set("@#{fsym}", @fields[fsym])
			}
			@mem_percent_free = percent_f(@memfree, @memtotal)
			@mem_percent_used = percent_f(@memtotal-@memfree, @memtotal)
			@swap_percent_free = percent_f(@swapfree, @swaptotal)
			@swap_percent_used = percent_f(@swaptotal-@swapfree, @swaptotal)
		end

		def percent_f(part, total)
			part.to_f/total*100
		end

		##
		# print percent with up to two digits, and strip off trailing 0s
		#
		def percent_to_s(val)
			("%.2f" % val).sub(/\.?0+$/, "")+"%"
		end

		def summary(stream)
			# "Memory Total=%s Free=%s Avail=%s [Free=%s Used=%s]\nSwap Total=%s Free=%s Used=%s [Free=%s Used=%s]\n" % [
			# 	@memtotal.to_bibyte, @memfree.to_bibyte, @memavailable.to_bibyte,
			# 	percent_to_s(@mem_percent_free), percent_to_s(@mem_percent_used),
			# 	@swaptotal.to_bibyte, @swapfree.to_bibyte, (@swaptotal-@swapfree).to_bibyte,
			# 	percent_to_s(@swap_percent_free), percent_to_s(@swap_percent_used)
			# ]
			headers = {
				rowlabel: "",
				total: "Total",
				used:	"Used",
				pused: "%Used",
				free: "Free",
				pfree: "%Free"
			}
			table = Tabular.new(headers)
			table.addrow({
				rowlabel: "Memory",
				total: @memtotal.to_bibyte,
				used: (@memtotal-@memfree).to_bibyte,
				pused: percent_to_s(@mem_percent_used),
				free: @memfree.to_bibyte,
				pfree: percent_to_s(@mem_percent_free)
			})
			table.addrow({
				rowlabel: "Swap",
				total: @swaptotal.to_bibyte,
				used: (@swaptotal-@swapfree).to_bibyte,
				pused: percent_to_s(@swap_percent_used),
				free: @swapfree.to_bibyte,
				pfree: percent_to_s(@swap_percent_free)
			})
			stream.puts table.to_s
		end
	end

	class MemInfoRecord < Hash
		KEYS=[ :total_mem, :free_mem, :avail_mem, :total_swap, :free_swap ]

		attr_reader :total_mem, :free_mem, :avail_mem, :total_swap, :free_swap
		##
		# double splat holds the keyword arguments like a hash keyed by the symbols
		# @param ts Time
		# @param keyword_arks
		#
		def initialize(ts, **keyword_args)
			ts = Time.parse(ts) if ts.class == String
			raise ArgumentError, "ts is not a Time or String variable" unless ts.class == Time
			@ts = ts
			KEYS.each { |key|
				val=keyword_args[key]
				self[key]=val
				instance_variable_set("@#{key}", val)
			}
		end

		##
		# create MemInfoRecord from MemInfo object for given timestamp (Time)
		#
		def self.create(ts, meminfo)
			MemInfoRecord.new(ts,
				total_mem: meminfo.memtotal,
				free_mem: meminfo.memfree,
				avail_mem: meminfo.memavailable,
				total_swap: meminfo.swaptotal,
				free_swap: meminfo.swapfree
			)
		end

		def to_json(*a)
			h={
				ts: @ts.to_s
			}
			KEYS.each { |key|
				h[key]=self[key]
			}
			h.to_json(*a)
		end

		def self.json_create(ts, dr)
			dr.keys.each { |key|
				dr[key.to_sym] = dr.delete(key)
			}
			MemInfoRecord.new(ts, dr)
		end
	end
end
