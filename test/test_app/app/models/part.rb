class Part < ApplicationRecord
  # can belong to car, or as a sub-part of a part.
  include ModelSerializer
  belongs_to :partable, :polymorphic => true

  has_many :parts, as: :partable
end
