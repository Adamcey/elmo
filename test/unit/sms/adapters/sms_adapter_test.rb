require 'test_helper'

class Sms::Adapters::SmsAdapterTest < ActiveSupport::TestCase
  setup do
    # copy settings 
    @mission = get_mission
    Setting.mission_was_set(@mission)
  end
  
  test "delivering a message with one recipient should work" do
    each_adapter do |adapter|
      assert_equal(true, adapter.deliver(Sms::Message.new(:to => %w(+15556667777), :body => "foo")))
    end
  end
  
  test "delivering an invalid message should raise an error" do
    each_adapter do |adapter|
      # no recips
      assert_raise(Sms::Error){adapter.deliver(Sms::Message.new(:to => nil, :body => "foo"))}
    
      # no body
      assert_raise(Sms::Error){adapter.deliver(Sms::Message.new(:to => %w(+15556667777), :body => ""))}
    end
  end
  
  private
  
    # loops over each known adapter and yields to a block
    def each_adapter(*args)
      Sms::Adapters::Factory.products.each do |klass|
        yield(klass.new)
      end
    end
end
