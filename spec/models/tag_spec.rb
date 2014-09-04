require 'spec_helper'

describe Tag do
  it "should force name to lowercase" do
    tag = create(:tag, name: 'ABC')
    expect(tag.reload.name).to eq 'abc'
  end

  describe "abilities" do
    subject(:ability) do
      user = double("Admin User", admin?: true).as_null_object
      Ability.new(user: user, mission: get_mission)
    end

    before { @tag = build(:tag) }

    context "if not standard copy" do
      before { allow(@tag).to receive_messages(standard_copy?: false) }

      it { should be_able_to :update, @tag }
      it { should be_able_to :destroy, @tag }
    end

    context "if standard copy" do
      before do
        allow(@tag).to receive_messages(standard_copy?: true)
        @tag.taggings << (@tagging = build(:tagging, tag: @tag))
      end

      context "with standard copy taggings" do
        before { allow(@tagging).to receive_messages(standard_copy?: true) }

        it { should_not be_able_to :update, @tag }
        it { should_not be_able_to :destroy, @tag }
      end

      context "without standard copy taggings" do
        before { allow(@tagging).to receive_messages(standard_copy?: false) }

        it { should be_able_to :update, @tag }
        it { should be_able_to :destroy, @tag }
      end

    end
  end

end
