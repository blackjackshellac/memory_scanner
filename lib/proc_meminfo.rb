
require_relative 'proc_common'
require_relative 'numeric_ext'

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

		def summary
			"Memory Total=%s Free=%s Avail=%s [Free=%s Used=%s]\nSwap Total=%s Free=%s Used=%s [Free=%s Used=%s]\n" % [
				@memtotal.to_bibyte, @memfree.to_bibyte, @memavailable.to_bibyte,
				percent_to_s(@mem_percent_free), percent_to_s(@mem_percent_used),
				@swaptotal.to_bibyte, @swapfree.to_bibyte, (@swaptotal-@swapfree).to_bibyte,
				percent_to_s(@swap_percent_free), percent_to_s(@swap_percent_used)
			]
		end
	end
end
