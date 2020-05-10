class User < ApplicationRecord
  has_many :vehicles

  def full_name
    "#{first_name} #{last_name}"
  end
end
