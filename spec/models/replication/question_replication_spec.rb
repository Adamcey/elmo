require 'spec_helper'

describe Question do
  before(:all) do
    @mission1 = create(:mission)
    @mission2 = create(:mission)
  end

  describe 'to_mission' do
    before do
      @orig = create(:question, qtype_name: 'select_one', is_standard: true)
      @copy = @orig.replicate(mode: :to_mission, dest_mission: @mission2)
    end

    context 'when replicating directly and copy exists in mission' do
      before do
        @copy2 = @orig.replicate(mode: :to_mission, dest_mission: @mission2)
      end

      it 'should make new copy but reuse option set' do
        expect(@copy).not_to eq @copy2
        expect(@copy.option_set).to eq @copy2.option_set
      end
    end
  end

  context 'old tests' do
    it "replicating a question within a mission should change the code" do
      q = FactoryGirl.create(:question, :qtype_name => 'integer', :code => 'Foo')
      q2 = q.replicate(:mode => :clone)
      assert_equal('Foo2', q2.code)
      q3 = q2.replicate(:mode => :clone)
      assert_equal('Foo3', q3.code)
      q4 = q3.replicate(:mode => :clone)
      assert_equal('Foo4', q4.code)
    end

    it "replicating a standard question should not change the code" do
      q = FactoryGirl.create(:question, :qtype_name => 'integer', :code => 'Foo', :is_standard => true)
      q2 = q.replicate(:mode => :to_mission, :dest_mission => get_mission)
      assert_equal(q.code, q2.code)
      q = FactoryGirl.create(:question, :qtype_name => 'integer', :code => 'Foo1', :is_standard => true)
      q2 = q.replicate(:mode => :to_mission, :dest_mission => get_mission)
      assert_equal(q.code, q2.code)
    end

    it "replicating a question should not replicate the key field" do
      q = FactoryGirl.create(:question, :qtype_name => 'integer', :key => true)
      q2 = q.replicate(:mode => :clone)

      assert_not_equal(q, q2)
      assert_not_equal(q.key, q2.key)
    end

    it "replicating a select question within a mission should not replicate the option set" do
      q = FactoryGirl.create(:question, :qtype_name => 'select_one')
      q2 = q.replicate(:mode => :clone)
      assert_not_equal(q, q2)
      assert_equal(q.option_set, q2.option_set)
    end

    it "replicating a standard select question should replicate the option set" do
      q = FactoryGirl.create(:question, :qtype_name => 'select_one', :is_standard => true)

      # ensure the std q looks right
      assert_nil(q.mission)
      assert_nil(q.option_set.mission)
      assert(q.option_set.is_standard)

      # replicate and test
      q2 = q.replicate(:mode => :to_mission, :dest_mission => get_mission)
      assert_not_equal(q, q2)
      assert_not_equal(q.option_set, q2.option_set)
      assert_not_equal(q.option_set.options.first, q2.option_set.options.first)
      assert_not_nil(q2.option_set.mission)
    end

    it "replicating question with short code that ends in zero should work" do
      q = FactoryGirl.create(:question, :qtype_name => 'integer', :code => 'q0')
      q2 = q.replicate(:mode => :clone)
      assert_equal('q1', q2.code)
    end

    it "name should be replicated on create" do
      q = FactoryGirl.create(:question, :is_standard => true, :name => 'Foo')
      q2 = q.replicate(:mode => :to_mission, :dest_mission => get_mission)
      assert_equal('Foo', q2.name)
      assert_equal('Foo', q2.canonical_name)
    end
  end
end
