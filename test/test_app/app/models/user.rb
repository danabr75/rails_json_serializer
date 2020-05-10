class User < ApplicationRecord
  has_many :cars

  def full_name
    "#{first_name} #{last_name}"
  end
end
