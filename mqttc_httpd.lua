unit = "NMCU1"
conn_tmr = 2000
loop_tmr = 600000
T1 = 7
R,G,B = 3,2,1

temp = function(pin)
  te = require("ds18b20")
  te.setup(pin)
  local temp = te.read()
  if temp == nil or temp == 85 then
    temp = "nil or 85"
  end  
--   print("pin"..pin..": "..temp.."")
  return temp
end

temp(T1)


gpio.mode(R, gpio.OUTPUT)
gpio.mode(G, gpio.OUTPUT)
gpio.mode(B, gpio.OUTPUT)


m = mqtt.Client(unit,60,"user","passwd")

m:lwt(unit, "offline", 0, 0)

m:on("offline", function(conn)
  print ("event offline")
  tmr.stop(1)
  connect()
end)

m:on("message", function(conn, topic, data)
  if data ~= nil then
    if (topic==unit.."/led/red/control") then
      cpin = R
    elseif (topic==unit.."/led/green/control") then
      cpin = G
    elseif (topic==unit.."/led/blue/control") then
      cpin = B
    end
    if (data=="1") then
      gpio.write(cpin,gpio.LOW)
    elseif (data=="0") then
      gpio.write(cpin,gpio.HIGH)
    end
  end
end)

publ = function()
  if wifi.sta.status() == 5 then
    m:publish(unit.."/temp1",temp(T1),0,0, function(conn)
      m:publish(unit.."/heap",node.heap(),0,0, function(conn)
        print("published temps and heap: "..node.heap().."")
      end)
    end)
    collectgarbage() 
  else
    tmr.stop(1)
    connect()
  end  
end

connect = function()
  wifi.sta.connect()
  tmr.alarm(0,conn_tmr,1,function() 
    if wifi.sta.status() < 5 then
      print("waiting for wifi")
    elseif wifi.sta.status() == 5 then
      print("connecting broker")
      m:connect("10.1.1.1",1883,0, function(conn) 
        tmr.stop(0)
        print("broker connected")
        m:subscribe(unit.."/led/blue/control",0,function(conn)
          m:subscribe(unit.."/led/green/control",0,function(conn)
            m:subscribe(unit.."/led/red/control",0,function(conn)
              print("subscribed")
            end)
          end)
        end)
        publ()
        tmr.alarm(1,loop_tmr,1,function()
          publ()
        end)
      end) 
    end   
  end)
end

connect() 

srv=net.createServer(net.TCP) 
srv:listen(80,function(httpd)
  httpd:on("receive", function(client,request)  
    header = "<!DOCTYPE html>\n<title>unit</title>\n<font size=\"5\" face=\"verdana\">\n"
    body = "Temp1: "..temp(T1).."<br>Heap: "..node.heap()..""
    client:send(header..body)
    client:close()
    collectgarbage()
  end)
end)

t = nil
ds18b20 = nil
package.loaded["ds18b20"]=nil

