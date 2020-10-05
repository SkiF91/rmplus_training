class RmptCategoriesController < ApplicationController
  self.main_menu = false

  before_action :require_login
  before_action :authorized_globaly?
  before_action :find_rmpt_category, only: [:update, :destroy, :move]

  def index
    @categories = RmptCategory.order(:lft)
  end

  def create
    @category = RmptCategory.new
    @category.safe_attributes = params[:rmpt_category]
    @category.save
  end

  def update
    @category.safe_attributes = params[:rmpt_category]
    @category.save
  end

  def destroy
    @category.destroy
  end

  def move
    @category.parent_id = params[:parent_id]
    if @category.save
      render json: { left_id: @category.left_sibling.try(:id), right_id: @category.right_sibling.try(:id), parent_id: @category.parent_id }
    else
      render json: { errors: view_context.error_messages_for(@category) }
    end
  end

  private

  def find_rmpt_category
    @category = RmptCategory.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end