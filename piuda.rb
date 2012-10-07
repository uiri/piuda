# -*- coding: utf-8 -*-
require 'cinch'
require 'cinch/logger/zcbot_logger'

class Bot < Cinch::Bot
  attr_accessor :topic, :memos, :helphash, :propernick, :pisgurl, :mustid

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

  def give_help(user, helptopic)
    if !helptopic
      helptopic = ""
    end
    if self.helphash[helptopic]
      user.msg(self.helphash[helptopic])
    else
      user.msg("Sorry I don't know how to help you with " + helptopic)
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

  def check_for_command(m, retval, helphash, private=false)
    if (m.message == "quit" && private == true) || self.simple_check("quit", m.message)
      self.can_quit(m.user, retval)
    elsif (m.message =~ /^help/ && private == true) || self.complex_check("help", m.message)
      self.give_help(m.user, m.message.split(' ', 2)[1])
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
      retval.each {|infos| m.user.msg(infos)}
    elsif (m.message =~ /^addinfo/ && private == true) || self.complex_check("addinfo", m.message)
      toadd = /addinfo (.+)$/.match(m.message)[1]
      retval.push(toadd)
      m.user.msg("Added \"#{toadd}\" to info list for ##conlang")
    elsif (m.message =~ /^rminfo/ && private == true) || self.complex_check("rminfo", m.message)
      retval = self.rm_info(m.user, retval, m.message)
    elsif (m.message == "fixnick" && private == true) || self.simple_check("fixnick", m.message)
      self.mustid = true
      self.config.nick = self.propernick
      self.nick = self.propernick
      self.set_nick(self.config.nick)
    end
    return retval
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
  @memos = {}
  @topic = []
  @propernick = configlist['nick']
  @pisgurl = configlist['pisgurl']
  @mustid = true
  infofile.each {|line| @topic.push(line) }
  infofile.close
  @helphash = {"" => "I am written in ruby, by Uiri. Check out the github repo! https://github.com/uiri/piuda",
    "commands" => "Available commands: addinfo, fixnick, help, info, memo, quit, rminfo, stats", 
    "addinfo" => "addinfo <text> - The text is added as a new line to the list of info messages",
    "fixnick" => "Forces the bot to change its nick to what it ought to be",
    "help" => "help <topic> - Gives a help message about topic or a message about itself",
    "info" => "Replies with the info messages",
    "memo" => "memo <user> <text> - Saves the text as a message for a user which is sent to the user the next time the bot receives a message from them either via query or in the channel",
    "quit" => "Shuts down the bot. Only works if you are coming from the same ip/host as the bot",
    "rminfo" => "rminfo <n> - Removes the nth line from the infolist. The first line is line '0'",
    "stats" => "Sends the URL for channel statistics. " + configlist['pisgurl']
  }

  on :private do |m|
    bot.topic = bot.check_for_command(m, bot.topic, bot.helphash, true)
    if m.user
      if bot.nick == bot.propernick
        if m.user.nick == "NickServ" && bot.mustid
          m.user.msg("identify "+bot.config.password)
          bot.mustid = false
        end
      end
      if bot.memos[m.user.nick] != [] && bot.memos[m.user.nick] != nil
        for tosend in bot.memos[m.user.nick] do
          m.user.msg(tosend)
        end
      end
    end
  end

  on :channel do |m|
    bot.topic = bot.check_for_command(m, bot.topic, bot.helphash)
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
bot.start
