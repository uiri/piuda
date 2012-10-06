# -*- coding: utf-8 -*-
require 'cinch'
require 'cinch/logger/zcbot_logger'

class Bot < Cinch::Bot
  attr_accessor :topic, :help, :helpcommands, :memos

  def simple_check(check, message)
    if message == "-" + check
      return true
    elsif message == self.nick + ": " + check
      return true
    else
      return false
    end
  end

  def complex_check(check, message)
    if message =~ /^-#{check}/
      return true
    elsif message =~ /^#{self.nick}: #{check}/
      return true
    else
      return false
    end
  end

  def rm_info(user, info, message)
    if Socket.getaddrinfo(user.host, 80)[0][3] == Socket.getaddrinfo(self.host, 80)[0][3]
      begin
        torem = / ((\d)+)$/.match(message)[1].to_i
      rescue
        torem = info.length - 1
      end
      if torem < info.length
        user.msg("Removed \"#{info[torem].chomp}\" from info list for ##conlang")
        info.delete_at(torem)
      else
        user.msg("I only accept numbers from 0 to #{info.length - 1}")
      end
    else
      user.msg("I don't trust you...")
    end
    return info
  end

  def can_quit(user, info)
    if Socket.getaddrinfo(user.host, 80)[0][3] == Socket.getaddrinfo(self.host, 80)[0][3]
      infofile = File.new("conlanginfo", 'w')
      info.each do |line|
        line.chomp!
        infofile.write(line + "\n")
      end
      self.quit("kal pan ym")
    else
      user.msg("You can't tell me what to do!")
    end
  end

  def check_for_command(m, responses, private=false)
    if (m.message == "quit" && private == true) || self.simple_check("quit", m.message)
      puts responses
      self.can_quit(m.user, responses[0])
    elsif (m.message == "help" && private == true) || self.simple_check("help", m.message)
      m.user.msg(responses[1])
    elsif (m.message == "help commands" && private == true) || self.simple_check("help commands", m.message)
      m.user.msg(responses[2])
    elsif (m.message =~ /^memo/ && private == true) || self.complex_check("memo", m.message)
      matches = /memo ([^ ]+) (.+)$/.match(m.message)
      if self.memos[matches[1]] == nil
        self.memos[matches[1]] = []
      end
      self.memos[matches[1]].push("<"+m.user.nick+"> "+matches[2])
      m.user.msg("Memo \"#{matches[2]}\" for user #{matches[1]} added.")
    elsif (m.message == "stats" && private == true) || self.simple_check("stats", m.message)
      m.user.msg("http://j.xqz.ca/pisg/")
    elsif (m.message == "info" && private == true) || self.simple_check("info", m.message)
      responses[0].each {|infos| m.user.msg(infos)}
    elsif (m.message =~ /^addinfo/ && private == true) || self.complex_check("addinfo", m.message)
      toadd = /addinfo (.+)$/.match(m.message)[1]
      responses[0].push(toadd)
      m.user.msg("Added \"#{toadd}\" to info list for ##conlang")
    elsif (m.message =~ /^rminfo/ && private == true) || self.complex_check("rminfo", m.message)
      responses[0] = self.rm_info(m.user, responses[0], m.message)
    elsif (m.message == "fixnick" && private == true) || self.simple_check("fixnick", m.message)
      self.config.nick = "Piuda"
      self.nick = "Piuda"
      self.set_nick(self.config.nick)
    end
    return responses[0]
  end
end

configfile = File.new("config", 'r')
configlist = {}
configfile.each{|line|
  line = line.strip
  if (line =~ /^#/) != 0
    breakdown = line.split("=")
    if breakdown[0] == "channels"
      breakdown[1] = breakdown[1].split(",")
    end
    configlist[breakdown[0]] = breakdown[1]
  end
}
bot = Bot.new do
  configure do |c|
    c.server = configlist['server']
    c.channels = configlist['channels']
    c.nick = configlist['nick']
    c.user = configlist['user']
    c.realname = configlist['realname']
    if configlist['password']
      c.password = configlist['password']
    end
  end

  pisglogfile = File.new("pisglog", 'a')
  pisglogger = Cinch::Logger::ZcbotLogger.new(pisglogfile)
  infofile = File.new("conlanginfo", 'r')
  @topic = []
  infofile.each {|line| @topic.push(line) }
  infofile.close
  @help = "I am written in ruby, by Uiri. Check out the github repo! https://github.com/uiri/piuda"
  @helpcommands = "I lied. http://i0.kym-cdn.com/photos/images/original/000/126/055/lied.gif"

  on :private do |m|
    bot.topic = bot.check_for_command(m, [bot.topic, bot.help, bot.helpcommands], true)
    if m.user
      if bot.memos[m.user.nick] != [] && bot.memos[m.user.nick] != nil
        for tosend in bot.memos[m.user.nick] do
          m.user.msg(tosend)
        end
      end
    end
  end

  on :channel do |m|
    bot.topic = bot.check_for_command(m, [bot.topic, bot.help, bot.helpcommands])
    if m.user
      if bot.memos[m.user.nick] != [] && bot.memos[m.user.nick] != nil
        for tosend in bot.memos[m.user.nick] do
          m.user.msg(tosend)
        end
        bot.memos[m.user.nick] = []
      end
    end
    pisglogger.log(m.raw, :incoming, :log)
    pisglogfile.flush
  end
end

bot.set_nick(bot.config.nick)
bot.memos = {}
bot.start
