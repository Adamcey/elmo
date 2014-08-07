require 'spec_helper'

describe Tag do
  before do
    @tag = create(:tag)
  end

  context "abilities" do
    before do
      @user = create(:user, admin: true)
      @ability = Ability.new(user: @user, mission: get_mission)
    end

    it "should normally allow editing and deleting" do
      expect(@ability).to be_able_to :update, @tag
      expect(@ability).to be_able_to :destroy, @tag
    end

    context "if copy of standard object" do
      before do
        allow(@tag).to receive_messages(standard_copy?: true)
      end

      it "should not allow editing" do
        expect(@ability).not_to be_able_to :update, @tag
      end

      it "should not allow deleting" do
        expect(@ability).not_to be_able_to :destroy, @tag
      end
    end
  end

end
