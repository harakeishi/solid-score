class Order < ApplicationRecord
  has_many :line_items
  belongs_to :user
  has_one :shipping_address

  validates :total, presence: true
  validates :status, presence: true

  scope :pending, -> { where(status: :pending) }
  scope :completed, -> { where(status: :completed) }

  enum status: { pending: 0, processing: 1, completed: 2, cancelled: 3 }

  before_save :calculate_total
  after_create :send_confirmation

  def complete!
    update!(status: :completed)
  end

  def cancel!
    update!(status: :cancelled)
  end

  private

  def calculate_total
    self.total = line_items.sum(&:price)
  end

  def send_confirmation
    # notification logic
  end
end
