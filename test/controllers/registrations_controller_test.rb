require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "signing up creates a non-admin user and logs them in" do
    assert_difference "User.count", 1 do
      post registration_path, params: {
        user: { name: "New Player", email_address: "new-player@example.com", password: "password123", password_confirmation: "password123" }
      }
    end

    user = User.find_by(email_address: "new-player@example.com")
    assert_not user.admin?
    assert_redirected_to root_path
  end

  test "cannot self-promote to admin via the signup form" do
    post registration_path, params: {
      user: { name: "Sneaky", email_address: "sneaky@example.com", password: "password123", password_confirmation: "password123", admin: true }
    }

    user = User.find_by(email_address: "sneaky@example.com")
    assert_not user.admin?
  end
end
