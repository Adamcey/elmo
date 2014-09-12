require 'spec_helper'

feature 'option suggestion dropdown', js: true do
  before do
    @user = create(:user, role_name: 'coordinator')
    login(@user)
  end

  scenario 'creating, showing, and editing' do
    click_link('Option Sets')

    # Fill in basic values
    click_link('Create New Option Set')
    fill_in('Name', with: 'Foo')
    check('Is Multilevel?')
    click_link('Add Level')
    fill_in('English', with: 'Typex')
    click_modal_save_button
    click_link('Add Level')
    fill_in('English', with: 'Species')
    click_modal_save_button
    all('#option_levels a.action_link_edit')[0].click # Click first pencil link.
    fill_in('English', with: 'Type') # Fix typo.
    click_modal_save_button

    # Go back to single level since dragging is hard here.
    2.times{ all('#option_levels a.action_link_remove')[0].click }
    uncheck('Is Multilevel?')

    add_options(%w(Banana Apple))

    click_button('Save')

    # Should redirect back to index page.
    expect(page).to have_selector('td.name_col a', text: 'Foo')

    # Test show mode (should have 'Apple' but no visible inputs or edit links).
    click_link('Foo')
    expect(page).to have_selector('#options-wrapper div', text: 'Apple')
    expect(page).not_to have_selector('form.option_set_form input[type=text]')
    expect(page).not_to have_selector('form.option_set_form a.action_link_edit')

    # Test edit mode (add another option)
    click_link('Edit Option Set')
    add_options(%w(Pear))
    click_button('Save')
    expect(page).to have_selector('td.options_col div', text: 'Banana, Apple, Pear')
  end

  def click_modal_save_button
    find('.modal-footer .btn-primary').click
  end

  def add_options(names)
    names.each do |name|
      fill_in('token-input-', with: name)
      find('div.token-input-dropdown-elmo li', text: "#{name} [Create New Option]").click
    end
    click_button('Add')
  end
end
