$forcenochrome=false
$stdout.sync=true
$eventmanager=EventManager.new
class WebGui::App
  attr_reader :windows
  def initialize(title,&block)
    $app=self
    if ARGV.length>0
      if ARGV[0]=="--forcenochrome"
        $forcenochrome=true
      end
    end
    @windows={}
    @windows[:main]=WebGui::Window.new(name: :main,title: title)
    @windows[:main].instance_eval(&block)
  end

  def render_document(wname)

    window=windows[wname]
    html=window.render
    css=window.render_css
    doc=<<-ENDDOC
<!DOCTYPE html>
<html>
  <head>
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.3.1/jquery.min.js"></script>
    <script src=\"main.js\"></script>
    <style>
      #{css}
    </style>
    <title>#{window.title}</title>
  </head>
  <body>
    #{html}
  </body>
</html>
    ENDDOC
    return doc
  end

  def add_window(wname,title,&block)
    @windows[wname]=WebGui::Window.new(name: wname,title: title)
    @windows[wname].instance_eval(&block)
  end
  def run()
    servthread=Thread.new do
      WebGui::Server.server(self)
    end
    startwsserv()
    if File.exists? "/Applications/Google\ Chrome.app" and !$forcenochrome
      `"/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome" --app="http://localhost:2000"`
    else
      puts "Chrome is not on your system."
      puts "Please install Chrome to use this framework properly."
      puts "If Chrome is installed, please make sure it is called Google Chrome.app and is in the root Applications folder."
      puts "The app will open in your default browser as a regular webpage instead."
      sleep(5)
      `open http://localhost:2000`
      servthread.join
    end
  end

  def startwsserv()
    @serv=WebGui::WebSocketServer.new
    Thread.new(self,@serv) do |parent,server|
      server.accept
      while true
        message=server.recv
        if message==false
          server.accept
          next
        end
        parent.handlemessage(message)
      end
    end
  end

  def handlemessage(message)
    puts "Got message #{message}"
    part1,val=message.split("=")
    type=part1.match /[a-zA-Z]+/.to_s
    type=type[0]
    id=part1.match /\d+/
    id=id[0].to_i
    if val
      case type
      when "menu"
        val=val.to_sym
      when "radiobutton"
        val=val.to_sym
      when "checkbox"
        vals=val.split("&")
        temp=[]
        vals.each do |val|
          temp.push(val.to_sym)
        end
        val=temp
      end
      $eventmanager.publish("#{type}.updated",val: val,id: id)
    else
      $eventmanager.publish("#{type}.pushed",id: id)
    end
  end

  def update(type,id,val)
    puts "Sent message #{type}#{id}=#{val}"
    @serv.send("#{type}#{id}=#{val}")
  end
end
