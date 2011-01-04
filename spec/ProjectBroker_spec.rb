require 'daemon/ProjectBroker'

RSpec.configure do |c|
  c.filter_run_excluding :ruby => lambda {|version|
    !(RUBY_VERSION.to_s =~ /^#{version.to_s}/)
  }
end

class TaskJuggler

  def TaskJuggler::runBroker(pb, key)
    pb.authKey = key
    pb.daemonize = false
    pb.logStdIO = false
    pb.port = 0
    # Don't generate any debug or info messages
    pb.log.outputLevel = 1
    pb.log.logLevel = 1
    t = Thread.new { pb.start }
    yield
    pb.stop
    t.join
  end

  describe ProjectBroker, :ruby => 1.9  do

    it "can be started and stopped" do
      @pb = ProjectBroker.new
      @authKey = 'secret'
      TaskJuggler::runBroker(@pb, @authKey) do
        true
      end
    end

  end

  describe ProjectBrokerIface, :ruby => 1.9 do

    before do
      @pb = ProjectBroker.new
      @pbi = ProjectBrokerIface.new(@pb)
      @authKey = 'secret'
    end

    describe "apiVersion" do

      it "should fail with bad authentication key" do
        TaskJuggler::runBroker(@pb, @authKey) do
          @pbi.apiVersion('bad key', 1).should == 0
        end
      end

      it "should pass with correct authentication key" do
        TaskJuggler::runBroker(@pb, @authKey) do
          @pbi.apiVersion(@authKey, 1).should == 1
        end
      end

      it "should fail with wrong API version", :ruby => 1.9 do
        TaskJuggler::runBroker(@pb, @authKey) do
          @pbi.apiVersion(@authKey, 0).should == -1
        end
      end

    end

    describe "command" do

      it "should fail with bad authentication key" do
        TaskJuggler::runBroker(@pb, @authKey) do
          @pbi.command('bad key', :status, []).should be_false
        end
      end

      it "should support 'status'" do
        TaskJuggler::runBroker(@pb, @authKey) do
          @pbi.command(@authKey, :status, []).should match \
            /.*No projects registered.*/
        end
      end

      it "should support 'terminate'" do
        TaskJuggler::runBroker(@pb, @authKey) do
          @pbi.command(@authKey, :stop, []).should be_nil
        end
      end

      it "should support 'add' and 'remove'" do
        TaskJuggler::runBroker(@pb, @authKey) do
          stdIn = StringIO.new("project foo 'foo' 2011-01-04 +1w task 'foo'")
          stdOut = StringIO.new
          stdErr = StringIO.new
          args = [ Dir.getwd, [ '.' ], stdOut, stdErr, stdIn, true ]
          @pbi.command(@authKey, :addProject, args).should be_true
          stdErr.string.should be_empty

          # Can't remove non-existing project bar
          @pbi.command(@authKey, :removeProject, 'bar').should be_false
          @pbi.command(@authKey, :removeProject, 'foo').should be_true
          # Can't remove foo twice
          @pbi.command(@authKey, :removeProject, 'foo').should be_false
        end
      end

    end

    describe "updateState" do

      it "should fail with bad authentication key" do
        TaskJuggler::runBroker(@pb, @authKey) do
          @pbi.updateState('bad key', 'foo', 'foo', :status, true).should \
            be_false
        end
      end

    end

  end

end
