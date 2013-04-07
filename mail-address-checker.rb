# -*- encoding: utf-8 -*-
require 'resolv'
require 'net/telnet'

class MailAddressChecker
  # 送信元として利用するドメイン(存在するドメインでないとダメな場合がある)
  MY_DOMAIN = "example.com"
  # telnetの最大待ち時間
  TIMEOUT = 10

  def self.get_exchange(domain)
    begin
      mx = Resolv::DNS.new.getresource(domain, Resolv::DNS::Resource::IN::MX)
    rescue
      return nil
    end
    return mx.exchange.to_s
  end

  def self.addrs_exist?(exchange, addrs)
    # 一応ユーザはランダムに生成
    user = ("a".."z").to_a.shuffle[0..7].join

    telnet = Net::Telnet.new("Host" => exchange, "Port" => 25, "Timeout" => TIMEOUT, "Prompt" => /^(250|550)/)
    telnet.cmd("helo #{MY_DOMAIN}")
    telnet.cmd("mail from: <#{user}@#{MY_DOMAIN}>")

    result = addrs.collect{|addr|
      reply = ""
      telnet.cmd("rcpt to: <" + addr + ">"){|c| reply << c}

      # ステータスコードを見る
      if reply =~ /^250/
        true
      else
        false
      end
    }

    telnet.cmd("String" => "quit")

    return result
  end

  def self.check addr
    # メールアドレスが正しい形式かチェック
    unless addr =~ (/^[a-zA-Z0-9_¥.¥-]+@[A-Za-z0-9_¥.¥-]+\.[A-Za-z0-9_¥.¥-]+$/)
      return {:exists => false, :valid => false, :message => "Invalid mail address."}
    end

    # SMTPサーバのアドレスを取得
    domain = addr.split("@")[1]
    exchange =  get_exchange(domain)
    unless exchange
      return {:exists => false, :valid => true, :message => "SMTP Server Not Found."}
    end

    # メールアドレスが存在するかどうか
    begin
      # ランダムなメールアドレスも加えてテスト
      result = addrs_exist?(exchange, [
        ("a".."z").to_a.shuffle[0..7].join + (0..9).to_a.shuffle[0..4].join + "@#{domain}",
        addr
      ])

      # ランダムなメールアドレスが存在する = 判定不能(SMTPサーバが嘘の応答をしているかも)
      if result[0]
        return {:exists => false, :valid => true, :message => "Check Failed.(maybe #{exchange} told a lie.)"}
      end

      if result[1]
        return {:exists => true, :valid => true, :message => "#{addr} exists."}
      else
        return {:exists => false, :valid => true, :message => "#{addr} does NOT exists."}
      end
    rescue
      return {:exists => false, :valid => true, :message => "Unknown Error.(maybe #{addr} does NOT exists.)"}
    end
  end
end

