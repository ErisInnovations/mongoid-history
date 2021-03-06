require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class MyModel
  include Mongoid::Document
  include Mongoid::History::Trackable
  field :foo
end

describe Mongoid::History::Trackable do
  it "should have #track_history" do
    MyModel.should respond_to :track_history
  end

  it "should append trackable_class_options ONLY when #track_history is called" do
    Mongoid::History.trackable_class_options.should be_blank
    MyModel.track_history
    Mongoid::History.trackable_class_options.keys.should == [:my_model]
  end

  describe "#track_history" do
    before :all do
      MyModel.track_history
      @persisted_history_options = Mongoid::History.trackable_class_options
    end
    before(:each){ Mongoid::History.trackable_class_options = @persisted_history_options }
    let(:expected_option) do
      { :on             =>  :all,
        :modifier_field =>  :modifier,
        :version_field  =>  :version,
        :scope          =>  :my_model,
        :except         =>  ["created_at", "updated_at"],
        :track_create   =>  false,
        :track_update   =>  true,
        :track_destroy  =>  false }
    end
    let(:regular_fields){ ["foo"] }
    let(:reserved_fields){ ["_id", "version", "modifier_id"] }

    it "should have default options" do
      Mongoid::History.trackable_class_options[:my_model].should == expected_option
    end

    it "should define callback function #track_update" do
      MyModel.new.private_methods.collect(&:to_sym).should include(:track_update)
    end

    it "should define callback function #track_create" do
      MyModel.new.private_methods.collect(&:to_sym).should include(:track_create)
    end

    it "should define callback function #track_destroy" do
      MyModel.new.private_methods.collect(&:to_sym).should include(:track_destroy)
    end

    it "should define #history_trackable_options" do
      MyModel.history_trackable_options.should == expected_option
    end

    describe "#tracked_fields" do
      it "should return the tracked field list" do
        MyModel.tracked_fields.should == regular_fields
      end
    end

    describe "#reserved_tracked_fields" do
      it "should return the protected field list" do
        MyModel.reserved_tracked_fields.should == reserved_fields
      end
    end

    describe "#tracked_fields_for_action" do
      it "should include the reserved fields for destroy" do
        MyModel.tracked_fields_for_action(:destroy).should == regular_fields + reserved_fields
      end
      it "should not include the reserved fields for update" do
        MyModel.tracked_fields_for_action(:update).should == regular_fields
      end
      it "should not include the reserved fields for create" do
        MyModel.tracked_fields_for_action(:create).should == regular_fields
      end
    end

    describe "#tracked_field?" do
      it "should not include the reserved fields by default" do
        MyModel.tracked_field?(:_id).should be_false
      end
      it "should include the reserved fields for destroy" do
        MyModel.tracked_field?(:_id, :destroy).should be_true
      end
      it "should allow field aliases" do
        MyModel.tracked_field?(:id, :destroy).should be_true
      end
    end

    context "sub-model" do
      before :each do
        class MySubModel < MyModel
        end
      end

      it "should have default options" do
        Mongoid::History.trackable_class_options[:my_model].should == expected_option
      end

      it "should define #history_trackable_options" do
        MySubModel.history_trackable_options.should == expected_option
      end
    end

    context "track_history" do

      it "should be enabled on the current thread" do
        MyModel.new.track_history?.should == true
      end

      it "should be disabled within disable_tracking" do
        MyModel.disable_tracking do
          MyModel.new.track_history?.should == false
        end
      end

      it "should be rescued if an exception occurs" do
        begin
          MyModel.disable_tracking do
            raise "exception"
          end
        rescue
        end
        MyModel.new.track_history?.should == true
      end

      it "should be disabled only for the class that calls disable_tracking" do
        class MyModel2
          include Mongoid::Document
          include Mongoid::History::Trackable
          track_history
        end

        MyModel.disable_tracking do
          MyModel2.new.track_history?.should == true
        end
      end

    end

  end
end
