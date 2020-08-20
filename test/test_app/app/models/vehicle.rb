class Vehicle < ApplicationRecord
  # include Serializer::Concern
  # Works with CAR
  # extend VehicleSerializer
  include ModelSerializer
  has_many :parts, as: :partable
  belongs_to :user

  def make_and_model
    "#{make} #{model}"
  end
end
