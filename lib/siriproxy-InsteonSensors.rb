require 'cora'
require 'siri_objects'
require 'pp'
require 'open-uri'
require 'nokogiri'

class SiriProxy::Plugin::InsteonSensors < SiriProxy::Plugin
  def initialize(config)
      appname = "SiriProxy-InsteonSensors"
      @host = config["insteon_hub_ip"]
      @port = config["insteon_hub_port"]
      rooms = File.expand_path('~/.siriproxy/house_config.yml')
      if (File::exists?( rooms ))
          @roomlist = YAML.load_file(rooms)
      end
  end
    
  def getStatus(sensorIDorig)
      sensorID = sensorIDorig.clone
      sensorID.insert(2,".")
      sensorID.insert(-3,".")
      sensorID.insert(-1,".01")
      
      sensorXML = Nokogiri::HTML(open("http://#{@host}:#{@port}/b.xml?01=01=F"))
      
      counter = 0
      foundmatch = 0
      statusline = 0
      status = ""
      
      sensorXML.xpath("//s").map { |line|
          line = line.to_s.chomp('"></s>').reverse.chomp('"=d s<').reverse
          if (sensorID == line)
              foundmatch = 1
              statusline = counter + 16
          end
          if (foundmatch == 1 && statusline == counter)
              if (line == "3B")
                  status = "open"
              end
              if (line == "3D")
                  status = "closed"
              end
              break
          end
          counter = counter + 1
      }
      sensorID.sub!(/^"\."/, "")
      return status
  end
    
  def find_active_room(macaddress)
    location = ""
    filename = macaddress.gsub(":","")
    filename = filename.gsub("\n","")
    filename = "#{filename}.siriloc"
    if (!File.exists?("#{filename}"))
        return false
    else
        File.open(filename).read.split("\n").each do |line|
            location = line
        end
        return location
    end
   end
    
   def has_sensors(location)
     if(location == "all")
         return true
     end
     if(@roomlist[location]["sensors"] == nil)
        return false
     else
        return true
     end
   end
 listen_for/^Are the kitchen doors open/i do
 
 end
    
 listen_for /^(?:Check the sensors|Security check|Check the security sensors)(?: in the | in my |)?(.*)?/i do |roomname|
    if (roomname == "leaving")
        roomname = "living room"
    end
    if (roomname == ("house") || roomname == (" house") || roomname == (" whole house") || roomname == ("whole house") || roomname == (" everywhere") || roomname == ("Holthaus")|| roomname == ("apartment")|| roomname == (" apartment") || roomname == ("whole apartment")|| roomname == (" whole apartment"))
        case roomname
            when 'house',' house', ' whole house', 'whole house', ' Holthaus'
                housename = "in the house"
            when ' everywhere'
                housename = "everywhere"
            when 'apartment', ' apartment', 'whole apartment', ' whole apartment'
                housename = "in the apartment"
        end
        currentLoc = "all"
    end
    if (roomname == "")
        deviceMAC = %x[arp -an | grep '(#{self.manager.device_ip})' | cut -d\\  -f4]
        currentLoc = find_active_room(deviceMAC)
        if (currentLoc == false)
            say "I don't know where you are.  Please tell me what room you are in."
        end
    else
        if (currentLoc != "all")
            currentLoc = roomname
        end
    end
    if (currentLoc == "all" || @roomlist.has_key?(currentLoc))
        if (has_sensors(currentLoc) == true)
            if (currentLoc == "all")
                say "Here is the status of sensors #{housename}"
                @roomlist.each { |room|
                    if (has_sensors(room[0]))
                        @roomlist[room[0]]["sensors"].each do |sensor|
                            sensorname = sensor["name"]
                            sensorid = sensor["id"]
                            sensortype = sensor["type"]
                            sensorstatus = getStatus(sensorid)
                            say "The #{room[0]} #{sensorname} #{sensortype} is #{sensorstatus}."
                        end
                    end
                }
            else
                say "Here is the status of the sensors in the #{currentLoc}:"
                @roomlist.each { |room|
                    if (room[0] == currentLoc)
                        @roomlist[room[0]]["sensors"].each do |sensor|
                            sensorname = sensor["name"]
                            sensorid = sensor["id"]
                            sensortype = sensor["type"]
                            sensorstatus = getStatus(sensorid)
                            say "The #{currentLoc} #{sensorname} #{sensortype} is #{sensorstatus}."
                        end
                    end
                }
            end
        else
            say "There are no sensors in the #{currentLoc}"
        end
    else
        say "There is no room defined called \"#{currentLoc}\""
    end
    request_completed
  end
end
