require 'torquespec/deployment_descriptor'

module TorqueSpec

  # Accepts any combination of hashes, filenames, or heredocs
  def deploy(*descriptors, &block)
    metaclass = class << self; self; end
    metaclass.send(:define_method, :deploy_paths) do
      return @deploy_paths if @deploy_paths
      FileUtils.mkdir_p(TorqueSpec.knob_root) unless File.exist?(TorqueSpec.knob_root)
      descriptors << block.call if block
      i = descriptors.size > 1 ? 0 : nil
      @deploy_paths = descriptors.map do |descriptor| 
        DeploymentDescriptor.new(descriptor, "#{self.display_name}#{i&&i-=1}").path
      end
    end
  end

  class << self
    attr_accessor :knob_root, :jboss_home, :jvm_args, :max_heap, :lazy, :drb_port
    def configure
      yield self
    end
    def jvm_args
      max_heap ? @jvm_args.sub(/-Xmx\w+/, "-Xmx#{max_heap}") : @jvm_args
    end
    def as7?
      File.exist?( File.join( jboss_home, "bin/standalone.sh" ) )
    end
  end

  # A somewhat hackish way of exposing client-side gems to the server-side daemon
  def self.rubylib
    here = File.dirname(__FILE__)
    rspec_libs = Dir.glob(File.expand_path(File.join(here, "../../..", "*{rspec,diff-lcs}*/lib")))
    this_lib = File.expand_path(File.join(here, ".."))
    rspec_libs.unshift( this_lib ).join(":")
  end

  # We must initialize the daemon with the same params as passed to the client
  def self.argv
    ( ARGV.empty? ? [ 'spec' ] : ARGV ).inspect
  end
end

# Default TorqueSpec options
TorqueSpec.configure do |config|
  config.drb_port = 7772
  config.knob_root = ".torquespec"
  config.jboss_home = ENV['JBOSS_HOME']
  config.jvm_args = "-Xms64m -Xmx1024m -XX:MaxPermSize=512m -XX:+UseConcMarkSweepGC -XX:+UseParNewGC -XX:+CMSClassUnloadingEnabled -Dgem.path=default"
end

