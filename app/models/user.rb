class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :accounts, dependent: :destroy
  has_many :tickets, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 6 }, on: :create
end
