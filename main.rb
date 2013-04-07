# -*- encoding: utf-8 -*-
require 'mail-address-checker'

mailaddr = ARGV[0]
status = MailAddressChecker.check mailaddr
puts status[:message]

