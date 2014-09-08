require 'spec_helper'

feature 'switching between missions and modes', js: true do
  before do
    @user = create(:user)
    @form = create(:sample_form)
    @mission1 = get_mission
    @mission2 = create(:mission)
    @user.assignments.create!(mission: @mission2, role: 'coordinator')
    login(@user)
  end

  scenario 'should work' do
    # We get logged in to mission2, so first test that changing to mission1 from mission2 root works.
    expect(current_url).to match(/mission2$/)
    select(@mission1.name, from: 'change_mission')

    # Smart redirect on mission change should work.
    # (Note this the controller logic for this is extensively tested in mission_change_redirect_spec but this test
    # ensures that the missionchange parameter is getting set by JS, etc.)
    click_link('Forms')
    click_link(@form.name)
    expect(page).to have_selector('h1.title', text: @form.name)
    select(@mission2.name, from: 'change_mission')
    expect(page).to have_selector('h1.title', text: 'Forms')
  end
end
