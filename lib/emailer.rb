
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
	class Emailer < Mail::Message

		def initialize(*args)
			super(args)
		end

		def setup(to:, from: nil, subject:, cc: nil, bcc: nil, comments: nil, keywords: nil, reply_to: nil, body:nil, files: [])
			self.to = to
			self.from = from.nil? ? to : from
			self.subject = subject
			self.body = body

			self.cc = cc unless cc.nil?
			self.bcc = bcc unless bcc.nil?
			self.comments = comments unless comments.nil?
			self.keywords = keywords unless keywords.nil?
			self.reply_to = reply_to unless reply_to.nil?

			attach(files)
		end

		def attach(files)
			# TODO deal with file attachments
			files = [ files ] if files.class == String
			files.each { |file|
				self.add_file(file)
			}
		end

		def send(body: nil, files:[], delivery_method: :sendmail)

			if block_given?
				self.body = "#{yield}"
			elsif !body.nil
				self.body = body
			end
			attach(files)
			self.delivery_method delivery_method
			self.deliver!
		end
	end
end
