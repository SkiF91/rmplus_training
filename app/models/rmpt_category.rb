class RmptCategory < ActiveRecord::Base
  include Redmine::SafeAttributes
  has_many :tests, class_name: 'RmptTest', foreign_key: :category_id, dependent: :nullify

  validates :name, presence: true

  acts_as_nested_set dependent: :destroy

  attr_reader :need_to_move_in_tree
  before_save :store_need_to_move_in_tree

  safe_attributes 'id', unsafe: true


  # override sorting of tree
  def name_upcase
    self.name.mb_chars.upcase
  end

  def move_to_new_parent
    return unless self.need_to_move_in_tree

    p = @move_to_new_parent_id ? self.class.find(@move_to_new_parent_id) : (self.send("saved_change_to_#{self.parent_column_name}?") ? nil : self.parent)
    move_to_ordered_child_of(p, 'name_upcase')
  end

  def move_to_ordered_child_of(parent, order_attribute, ascending = true)
    if parent
      super(parent, order_attribute, ascending)
    else
      return if self.class.roots.size == 1

      left_neighbor = self.find_left_neighbor_root(order_attribute, ascending)

      if left_neighbor
        self.move_to_right_of(left_neighbor)
      else
        self.move_to_left_of(self.class.roots[0])
      end
    end
  end

  def find_left_neighbor_root(order_attribute, ascending)
    left = nil
    self.class.roots.each do |n|
      if ascending
        left = n if n.send(order_attribute) < self.send(order_attribute)
      else
        left = n if n.send(order_attribute) > self.send(order_attribute)
      end
    end
    left
  end
  # end overriding sort
  private

  def store_need_to_move_in_tree
    @need_to_move_in_tree = (self.new_record? || self.send("#{self.parent_column_name}_changed?") || self.name_changed?)
    true
  end
end