class RecipesController < ApplicationController
  skip_before_filter :authorize, :only => [:index, :search, :show, :create_from_import]
  expose(:paged_recipes) { Recipe.includes(:pictures).paginate :page => params[:page], :per_page => 15, :order => 'created_at DESC' }
  expose(:recipe_results) { Recipe.includes(:pictures).search(params[:search], sort_column, sort_direction, params[:page]) }
  expose(:recipe)
  expose(:favorite) { Favorite.new } # had to use new - it was trying to find by params[:id]
  helper_method :sort_column, :sort_direction

  def index
    if !current_user && request.fullpath == '/'
      render "static/home" and return
    end

    paged_recipes.each do |recipe|
      recipe.replace_pipes
    end
  end

  def search
    if recipe_results.empty?
      flash.now[:notice] = "Sorry, you searched for '#{params[:search]}' and no results were found."
    end
  end

  def edit
    recipe.replace_pipes "\n\n", [:directions]
    recipe.replace_pipes "\n", [:ingredients]
  end

  def create
    if recipe.save
      Favorite.create(:user_id => current_user.id, :recipe_id => recipe.id)
      redirect_to(recipe, :notice => 'Recipe was successfully created.')
    else
      render :action => "new"
    end
  end

  def create_from_import
    url = params[:source_url]
    recipe = Recipe.from_import(url)
    recipe.user_id = current_user.id

    if recipe.save
      Favorite.create(:user_id => current_user.id, :recipe_id => recipe.id)
      redirect_to(recipe, :notice => 'Recipe was successfully created.')
    elsif recipe.errors[:source_url] == ['has already been taken']
      redirect_to(import_recipes_url, :notice => "Sorry, that recipe has already been imported.")
    else
      redirect_to(import_recipes_url, :notice => "Sorry, there was a problem creating a recipe from #{url}. That site may not be supported at this time.")
    end
  end

  def update
    if recipe.save
      redirect_to(recipe, :notice => 'Recipe was successfully updated.')
    else
      render :action => "edit"
    end
  end

  def destroy
    recipe.destroy
    redirect_to recipes_path, :notice => 'Recipe was deleted'
  end

  private

  # sanitize params and provide defaults to prevent sql injection
  def sort_column
    Recipe.column_names.include?(params[:sort]) ? params[:sort] : nil
  end

  # sanitize params and provide defaults to prevent sql injection
  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : "asc"
  end
end
