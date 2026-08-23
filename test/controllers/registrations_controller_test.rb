require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "signing up creates a non-admin user and logs them in" do
    assert_difference "User.count", 1 do
      post registration_path, params: {
        user: { name: "12 New Player", email_address: "new-player@student.gs.chiba-u.jp", password: "password123", password_confirmation: "password123" }
      }
    end

    user = User.find_by(email_address: "new-player@student.gs.chiba-u.jp")
    assert_not user.admin?
    assert_redirected_to root_path
  end

  test "cannot self-promote to admin via the signup form" do
    post registration_path, params: {
      user: { name: "12 Sneaky", email_address: "sneaky@student.gs.chiba-u.jp", password: "password123", password_confirmation: "password123", admin: true }
    }

    user = User.find_by(email_address: "sneaky@student.gs.chiba-u.jp")
    assert_not user.admin?
  end

  test "rejects an email address outside the student domain" do
    assert_no_difference "User.count" do
      post registration_path, params: {
        user: { name: "12 Outsider", email_address: "outsider@example.com", password: "password123", password_confirmation: "password123" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "rejects a name that isn't 学籍番号 + 氏名" do
    assert_no_difference "User.count" do
      post registration_path, params: {
        user: { name: "名前だけ", email_address: "no-number@student.gs.chiba-u.jp", password: "password123", password_confirmation: "password123" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "a failed signup redisplays the form with the entered name and email kept" do
    post registration_path, params: {
      user: { name: "名前だけ", email_address: "kept@student.gs.chiba-u.jp", password: "password123", password_confirmation: "password123" }
    }

    assert_response :unprocessable_entity
    assert_select "input[name='user[name]'][value=?]", "名前だけ"
    assert_select "input[name='user[email_address]'][value=?]", "kept@student.gs.chiba-u.jp"
  end
end
