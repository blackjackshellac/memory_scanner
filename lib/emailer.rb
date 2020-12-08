
# gem install mail
begin
	require 'mail'
rescue LoadError => e
	puts "Install the mail gem\n\n\t$ gem install mail\n"
	exit 1
end

# mail = Mail.new do
#   from     'me@test.lindsaar.net'
#   to       'you@test.lindsaar.net'
#   subject  'Here is the image you wanted'
#   body     File.read('body.txt')
#   add_file :filename => 'somefile.png', :content => File.read('/somefile.png')
# end
#
# mail.deliver!

module Notify
	class Emailer

		attr_reader :mail
		def initialize(to:, from: nil, subject:)
			@mail = Mail.new
			@mail.to = to
			@mail.from = from.nil? ? @to : from
			@mail.subject = subject
		end

		def setup(to:, from: nil, subject:, cc: nil, bcc: nil, comments: nil, keywords: nil, reply_to: nil, body:, files: [])
			@mail.to = to
			@mail.from = from.nil? ? to : from
			@mail.subject = subject
			@mail.body = body

			@mail.cc = cc unless cc.nil?
			@mail.bcc = bcc unless bcc.nil?
			@mail.comments = comments unless comments.nil?
			@mail.keywords = keywords unless keywords.nil?
			@mai.reply_to = reply_to unless reply_to.nil?

			# TODO deal with file attachments
			
		end
	end
end
