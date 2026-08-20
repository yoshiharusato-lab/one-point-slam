require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires a name" do
    user = User.new(email_address: "no-name@example.com", password: "password123")
    assert_not user.valid?
    assert user.errors[:name].present?
  end

  test "requires a unique, normalized email address" do
    User.create!(name: "First", email_address: "Dup@Example.com", password: "password123")
    dup = User.new(name: "Second", email_address: "dup@example.com", password: "password123")

    assert_not dup.valid?
    assert dup.errors[:email_address].present?
  end
end
