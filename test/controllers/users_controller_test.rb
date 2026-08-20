require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(name: "avatar-user", email_address: "avatar-user@example.com", password: "password123")
    @other_user = User.create!(name: "other-user", email_address: "other-user@example.com", password: "password123")
  end

  test "a user can upload their own avatar" do
    sign_in_as @user

    file = fixture_file_upload("avatar.jpg", "image/jpeg")
    patch user_path(@user), params: { user: { avatar: file } }

    assert_redirected_to @user
    assert @user.reload.avatar.attached?
  end

  test "a user cannot change someone else's avatar" do
    sign_in_as @user

    file = fixture_file_upload("avatar.jpg", "image/jpeg")
    patch user_path(@other_user), params: { user: { avatar: file } }

    assert_not @other_user.reload.avatar.attached?
  end

  test "rejects a non-image upload" do
    sign_in_as @user

    file = fixture_file_upload("not_an_image.txt", "text/plain")
    patch user_path(@user), params: { user: { avatar: file } }

    assert_redirected_to @user
    assert_not @user.reload.avatar.attached?
  end
end
