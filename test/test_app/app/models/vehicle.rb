class Vehicle < ApplicationRecord
  self.abstract_class = true
  has_many :parts, as: :partable
  belongs_to :user

  def make_and_model
    "#{make} #{model}"
  end
end
