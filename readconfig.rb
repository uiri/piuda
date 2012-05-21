  configfile = File.new("config", 'r')
  configlist = {}
  configfile.each{|line|
    if (line =~ /^#/) != 0
      breakdown = line.split("=")
      if breakdown[0] == "channels"
        breakdown[1] = breakdown[1].split(",")
      end
      configlist[breakdown[0]] = breakdown[1]
      puts breakdown[1].to_s
    else
      puts "A comment"
    end
  }
  puts configlist['password']
