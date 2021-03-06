require_relative '../spec_helpers'
require "socket"


describe KRPC::Connection do

  before :all do
    server_start
  end
  after :all do
    server_stop
  end

  before :each do
    @connection = connect
  end
  after :each do
    @connection.close
  end


  def server_start
    @server = TCPServer.open(0)
    @server_port = @server.addr[1]

    @server_thread = Thread.new do
      while (conn = @server.accept)
        loop {
          data = conn.recv(2**16)
          break if data.empty?
          conn.send(data, 0)
        }
        conn.close
      end
    end
  end

  def server_stop
    @server_thread.terminate
    @server_port = nil
    @server.close
  end

  def connect
    KRPC::Connection.new("localhost", @server_port).connect
  end


  specify "send & receive" do
    @connection.send "foo"
    expect(@connection.recv(3)).to eq "foo"
  end

  specify "long send & long receive" do
    msg = "foo" * 4096
    @connection.send msg
    expect(@connection.recv(msg.length)).to eq msg
  end

  specify "send & receive varint" do
    int = 83752476526753
    msg = KRPC::ProtobufUtils::Encoder.encode_varint(int)
    @connection.send msg
    expect(@connection.recv_varint).to eq int
  end

  specify "#connected?" do
    expect(@connection.connected?).to be true
    expect(@connection.connected?).to be true
    @connection.close
    expect(@connection.connected?).to be false
    expect(@connection.connected?).to be false
  end

  specify "double close handling" do
    expect(@connection.close).to be true
    expect(@connection.close).to be false
  end

  specify "#trim_fill" do
    trim_fill = @connection.method(:trim_fill)
    expect(trim_fill.call("", 5)).to eq "\x00"*5
    expect(trim_fill.call("abc", 10)).to eq "abc" + "\x00"*7
    expect(trim_fill.call("abc"*4, 10)).to eq "abc"*3 + "a"
  end

end
