require "spec_helper"

describe Form do

  context "API User" do
    before do
      @api_user = FactoryGirl.create(:user)
      @mission = FactoryGirl.create(:mission, name: "test mission")
      @form = FactoryGirl.create(:form, mission: @mission, name: "something", access_level: 'protected')
      @form.whitelist_users.create(user_id: @api_user.id)
    end

    it "should return true for user in whitelist" do
      expect(@form.api_user_id_can_see?(@api_user.id)).to be_truthy
    end

    it "should return false for user not in whitelist" do
      other_user = FactoryGirl.create(:user)
      expect(@form.api_user_id_can_see?(other_user.id)).to be_falsey
    end
  end

  describe 'update_ranks' do
    before do
      # Create form with condition (#3 referring to #2)
      @form = create(:form, question_types: %w(integer select_one integer))
      @qings = @form.questionings
      @qings[2].create_condition(ref_qing: @qings[1], op: 'eq', option: @qings[1].options[0])

      # Move question #1 down to position #3 (old #2 and #3 shift up one).
      @old_ids = @qings.map(&:id)

      # Without this, this test was not raising a ConditionOrderingError that was getting raised in the wild.
      # ORM can be a pain sometimes!
      @form.reload

      @form.update_ranks(@old_ids[0] => 3, @old_ids[1] => 1, @old_ids[2] => 2)
      @form.save!
    end

    it 'should update ranks and not raise order invalidation error' do
      expect(@form.reload.questionings.map(&:id)).to eq [@old_ids[1], @old_ids[2], @old_ids[0]]
    end
  end

  describe 'pub_changed_at' do
    before do
      @form = create(:form)
    end

    it 'should be nil on create' do
      expect(@form.pub_changed_at).to be_nil
    end

    it 'should be updated when form published' do
      @form.publish!
      expect(@form.pub_changed_at).to be_within(0.01).of(Time.zone.now)
    end

    it 'should be updated when form unpublished' do
      publish_and_reset_pub_changed_at
      @form.save!
      @form.unpublish!
      expect(@form.pub_changed_at).to be_within(0.01).of(Time.zone.now)
    end

    it 'should not be updated when form saved otherwise' do
      publish_and_reset_pub_changed_at
      @form.name = 'Something else'
      @form.save!
      expect(@form.pub_changed_at).not_to be_within(5.minutes).of(Time.zone.now)
    end
  end

  describe 'needs_odk_manifest?' do
    context 'for form with single level option sets only' do
      before { @form = create(:form, question_types: %w(select_one)) }
      it 'should return false' do
        expect(@form.needs_odk_manifest?).to be false
      end
    end
    context 'for form with multi level option set' do
      before { @form = create(:form, question_types: %w(select_one multi_level_select_one)) }
      it 'should return true' do
        expect(@form.needs_odk_manifest?).to be true
      end
    end
  end

  def publish_and_reset_pub_changed_at
    @form.publish!
    @form.pub_changed_at -= 1.hour
  end
end
