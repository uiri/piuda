# -*- coding: utf-8 -*-
require 'cinch'

class Bot < Cinch::Bot

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
    if user.host == self.host
      begin
        torem = / ((\d)+)$/.match(message)[1].to_i
      rescue
        torem = info.length - 1
      end
      if torem < info.length
        user.msg("Removed \"#{info[torem].chomp}\" from info list for #conlang")
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
    if user.host == self.host
      infofile = File.new("conlanginfo", 'w')
      info.each {|line| infofile.write(line)}
      self.quit("Bye")
    else
      user.msg("You can't tell me what to do!")
    end
  end

  def check_for_command(m, responses, private=false)
    if (m.message == "quit" && private == true) || self.simple_check("quit", m.message)
      self.can_quit(m.user, responses[0])
    elsif (m.message == "help" && private == true) || self.simple_check("help", m.message)
      m.user.msg(responses[1])
    elsif (m.message == "help commands" && private == true) || self.simple_check("help commands", m.message)
      m.user.msg(responses[2])
    elsif (m.message == "info" && private == true) || self.simple_check("info", m.message)
      responses[0].each {|infos| m.user.msg(infos)}
    elsif (m.message =~ /^addinfo/ && private == true) || self.complex_check("addinfo", m.message)
      toadd = /addinfo (.+)$/.match(m.message)[1]
      responses[0].push(toadd)
      m.user.msg("Added \"#{toadd}\" to info list for #conlang")
    elsif (m.message =~ /^rminfo/ && private == true) || self.complex_check("rminfo", m.message)
      responses[0] = self.rm_info(m.user, responses[0], m.message)
    elsif (m.message == "fixnick" && private == true) || self.simple_check("fixnixk", m.message)
      self.nick = "Piuda"
    end
    return responses[0]
  end
end

bot = Bot.new do
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
  configure do |c|
    c.server = configlist['server']
    c.channels = configlist['channels']
    c.nick = configlist['nick']
    c.user = configlist['user']
    c.realname = configlist['realname']
    if configlist['password']
      c.password = configlist['password']
    end
    infofile = File.new("conlanginfo", 'r')
    @info = []
    infofile.each {|line| @info.push(line) }
    infofile.close
    @help = "I am written in ruby, by Uiri. Check out the github repo! https://github.com/uiri/piuda"
    @helpcommands = "I lied. http://i0.kym-cdn.com/photos/images/original/000/126/055/lied.gif"
  end

  on :private do |m|
    @info = bot.check_for_command(m, [@info, @help, @helpcommands], true)
  end

  on :channel do |m|
    @info = bot.check_for_command(m, [@info, @help, @helpcommands])
  end
end

bot.start
