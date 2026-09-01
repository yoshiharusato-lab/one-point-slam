require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires a name" do
    user = User.new(email_address: "no-name@student.gs.chiba-u.jp", password: "password123")
    assert_not user.valid?
    assert user.errors[:name].present?
  end

  test "requires a unique, normalized email address" do
    User.create!(name: "11 First", email_address: "DUP@student.gs.chiba-u.jp", password: "password123")
    dup = User.new(name: "22 Second", email_address: "dup@student.gs.chiba-u.jp", password: "password123")

    assert_not dup.valid?
    assert dup.errors[:email_address].present?
  end

  test "requires the email address to be on the student.gs.chiba-u.jp domain" do
    user = User.new(name: "11 Outsider", email_address: "someone@example.com", password: "password123")

    assert_not user.valid?
    assert user.errors[:email_address].present?
  end

  test "requires the name to be 学籍番号 + 氏名" do
    user = User.new(name: "千葉太郎", email_address: "no-number@student.gs.chiba-u.jp", password: "password123")

    assert_not user.valid?
    assert user.errors[:name].present?
  end

  test "accepts a name in the 学籍番号 氏名 format" do
    user = User.new(name: "12 千葉太郎", email_address: "chiba-taro@student.gs.chiba-u.jp", password: "password123")

    assert user.valid?
  end

  test "rejects a 1-digit 学籍番号" do
    user = User.new(name: "1 千葉太郎", email_address: "one-digit@student.gs.chiba-u.jp", password: "password123")

    assert_not user.valid?
    assert user.errors[:name].present?
  end

  test "rejects a 3-or-more-digit 学籍番号" do
    user = User.new(name: "123 千葉太郎", email_address: "three-digit@student.gs.chiba-u.jp", password: "password123")

    assert_not user.valid?
    assert user.errors[:name].present?
  end

  test "an account predating the name/email format rules can still update unrelated fields" do
    legacy = User.new(name: "千葉太郎", email_address: "legacy@example.com", password: "password123")
    legacy.save!(validate: false)

    legacy.day2_attending = true
    assert legacy.save, legacy.errors.full_messages.to_s
  end

  test "changing the name on a legacy account still enforces the format" do
    legacy = User.new(name: "千葉太郎", email_address: "legacy2@example.com", password: "password123")
    legacy.save!(validate: false)

    legacy.name = "also not the right format"
    assert_not legacy.save
    assert legacy.errors[:name].present?
  end
end
