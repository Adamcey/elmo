require 'spec_helper'

feature 'option suggestion dropdown', js: true do
  before do
    @user = create(:user)
    login(@user)
  end

  scenario 'should drop down' do
    visit new_option_set_path(:mode => 'm', :mission_name => get_mission.compact_name, :locale => 'en')
    expect(page).not_to have_selector('div.token-input-dropdown-elmo li')
    fill_in 'token-input-', :with => 'y'
    expect(find('div.token-input-dropdown-elmo li')).to have_content('y [Create New Option]')
  end
end
