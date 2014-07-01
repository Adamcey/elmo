require 'test_helper'

class SmsConsoleTest < ActionDispatch::IntegrationTest

  test "going to the page to create a new sms should succeed" do
    user = get_user
    login(user)

    get new_sms_test_path(:mission_name => get_mission.compact_name)

    assert_response :success
  end

end
