require 'socket' # Provides TCPServer and TCPSocket classes
require 'digest/sha1'

class WebSocketServer
  def initialize(host="localhost",port=2345)
    @server=TCPServer.new(host,port)
  end

  def accept()

    # Wait for a connection
    @socket = @server.accept

    # Read the HTTP request. We know it's finished when we see a line with nothing but \r\n
    http_request = ""
    while (line = @socket.gets) && (line != "\r\n")
      http_request += line
    end

    # Grab the security key from the headers. If one isn't present, close the connection.
    if matches = http_request.match(/^Sec-WebSocket-Key: (\S+)/)
      websocket_key = matches[1]
    else
      socket.close
      return
    end
    response_key = Digest::SHA1.base64digest([websocket_key, "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"].join)
    @socket.write <<-eos
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: #{response_key}

    eos
  end

  def recv()
    first_byte = @socket.getbyte
    fin = first_byte & 0b10000000
    opcode = first_byte & 0b00001111
    fin = fin >> 7
    fin = (fin ? true : false)
    raise "We don't support continuations" unless fin
    unless opcode == 1 or opcode == 8
      raise "We only support text data and close frame"
      send("",3)
    end
    if opcode == 1
      second_byte = @socket.getbyte
      is_masked = second_byte & 0b10000000
      payload_size = second_byte & 0b01111111

      raise "All incoming frames should be masked according to the websocket spec" unless is_masked
      raise "We only support payloads < 126 bytes in length" unless payload_size < 126
      mask = 4.times.map {@socket.getbyte}
      data = payload_size.times.map {@socket.getbyte}
      unmasked_data = data.each_with_index.map { |byte, i| byte ^ mask[i % 4] }
      string=unmasked_data.pack('C*').force_encoding('utf-8')
      return string
    elsif opcode == 8
      send("",0)
      return false
    end
  end

  def send(message,closetype=false)
    if closetype
      output=[0x88,2,3,0xe8+closetype]
      @socket.write output.pack("C*")
      @socket.close
    else
      output = [0x81, message.size, message]
      @socket.write output.pack("CCA#{message.size}")
    end
  end
end
