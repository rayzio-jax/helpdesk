require "test_helper"

class TicketsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get tickets_index_url
    assert_response :success
  end

  test "should get push" do
    get tickets_push_url
    assert_response :success
  end

  test "should get poll" do
    get tickets_poll_url
    assert_response :success
  end
end
