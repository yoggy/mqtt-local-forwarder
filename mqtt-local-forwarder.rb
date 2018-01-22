#!/usr/bin/ruby
#
#  mqtt-local-forwarder.rb 
#
#  github:
#    htt@s://github.com/yoggy/mqtt-local-forwarder
#
#  license:
#    Copyright(c) 2018 yoggy<yoggy0@gmail.com>
#    Released under the MIT license
#    http://opensource.org/licenses/mit-license.php;
#
require 'mqtt'
require 'yaml'
require 'ostruct'
require 'csv'
require 'pp'

$stdout.sync = true
Dir.chdir(File.dirname($0))
$current_dir = Dir.pwd

$log = Logger.new(STDOUT)
$log.level = Logger::DEBUG

$conf = OpenStruct.new(YAML.load_file("config.yaml"))

conn_opts = {
  remote_host: $conf.mqtt_host
}

if !$conf.mqtt_port.nil?
  conn_opts["remote_port"] = $conf.mqtt_port
end

if $conf.mqtt_use_auth == true
  conn_opts["username"] = $conf.mqtt_username
  conn_opts["password"] = $conf.mqtt_password
end

# subscribe topic -> publish topic
csv = CSV.read("table.csv")
map = {}

csv.each do |l|
  next unless l.size == 2

  subscribe_topic = l[0].strip
  publish_topic   = l[1].strip

  next if subscribe_topic[0] == "#" # comment line

  map[subscribe_topic] = publish_topic
  $log.info "subscribe_topic=#{subscribe_topic}, publish_topic=#{publish_topic}"
end

$log.info "connecting..."
MQTT::Client.connect("127.0.0.1") do |src|
  MQTT::Client.connect(conn_opts) do |dst|
    $log.info "connected!"

    map.each do |k, v|
      src.subscribe(k)
    end

    src.get do |topic, message|
      publish_topic = map[topic]
      return if publish_topic.nil?

      $log.info "recv: topic=#{topic}, message=#{message} -> publish_topic=#{publish_topic}"
      dst.publish(publish_topic, message)
    end
  end
end

