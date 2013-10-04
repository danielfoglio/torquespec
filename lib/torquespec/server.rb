# Copyright 2013 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'net/http'
require 'torquespec/as6'
require 'torquespec/as7'

module TorqueSpec
  class Server

    def initialize
      self.extend( TorqueSpec.as7? ? AS7 : AS6 )
      self.extend( Domain ) if TorqueSpec.domain_mode
    end

    def message(s)
      RSpec.configuration.reporter.message(s) if TorqueSpec.verbose?
    end
    
    def start(opts={})
      if ready?
        if TorqueSpec.lazy
          message "Using running JBoss (try lazy=false if you get errors)"
          return
        else
          stop
          message "Waiting for running JBoss to shutdown"
          sleep(5)
          sleep(1) while ready?
          self.stopped = false
        end
      end
      startup(opts)
    end

    def stop
      return if stopped
      self.stopped = true
      if TorqueSpec.lazy
        message "JBoss won't be stopped (lazy=true)"
      else
        shutdown
        message "Shutdown message sent to JBoss"
      end
    end

    def deploy(url)
      t0 = Time.now
      message "deploy #{url}"
      _deploy(url)
      message "deployed in #{(Time.now - t0).to_i}s"
    end

    def undeploy(url)
      begin
        _undeploy(url)
      rescue Exception=>e 
        $stderr.puts `jstack #{self.server_pid}`
        raise e
      end
    end

    def wait_for_ready(timeout)
      message "Waiting up to #{timeout}s for JBoss to boot"
      t0 = Time.now
      while (Time.now - t0 < timeout && !stopped) do
        if ready?
          message "JBoss started in #{(Time.now - t0).to_i}s"
          return true
        end
        sleep(1)
      end
      raise "JBoss failed to start"
    end

    protected

    def startup(opts)
      ENV.delete 'RUBYOPTS' # nukes bundler as injected by rails apps in their test specs
      wait = opts[:wait].to_i
      cmd = start_command
      process = IO.popen( cmd )
      self.server_pid = process.pid
      Thread.new(process) { |console| while(console.gets); end }
      %w{ INT TERM KILL }.each { |signal| trap(signal) { stop } }
      message "#{cmd}\npid=#{process.pid}"
      wait > 0 ? wait_for_ready(wait) : process.pid
    end

    def post(path, params)
      req = Net::HTTP::Post.new(path)
      req.content_type = "application/json"
      if (params.is_a? Hash)
        req.set_form_data( params )
      else
        req.body = params
      end
      http( req )
    end

    def http req
      res = Net::HTTP.start('localhost', port) do |http| 
        http.read_timeout = 360
        http.request(req)
      end
      unless Net::HTTPSuccess === res
        $stderr.puts res.body
        res.error!
      end
      res.body
    end

    attr_accessor :stopped
    attr_accessor :server_pid
  end

end

