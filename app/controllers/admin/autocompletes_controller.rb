# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
class Admin::AutocompletesController < Admin::ApplicationController
  before_filter "set_current_tab('admin/autocompletes')", :only => [ :index, :show ]

  load_resource

  # GET /admin/autocompletes
  # GET /admin/autocompletes.xml                                                   HTML
  #----------------------------------------------------------------------------
  def index
    @autocompletes = Autocomplete.all
    respond_with(@autocompletes)
  end

  # GET /admin/autocompletes/new
  # GET /admin/autocompletes/new.xml                                               AJAX
  #----------------------------------------------------------------------------
  def new
    respond_with(@autocomplete)
  end

  # GET /admin/autocompletes/1/edit                                                AJAX
  #----------------------------------------------------------------------------
  def edit
    if params[:previous].to_s =~ /(\d+)\z/
      @previous = Autocomplete.find_by_id($1) || $1.to_i
    end
  end

  # POST /admin/autocompletestags
  # POST /admin/autocompletes.xml                                                  AJAX
  #----------------------------------------------------------------------------
  def create
    @autocomplete.update_attributes(params[:autocomplete])

    respond_with(@autocomplete)
  end

  # PUT /admin/autocompletes/1
  # PUT /admin/autocompletes/1.xml                                                 AJAX
  #----------------------------------------------------------------------------
  def update
    @autocomplete.update_attributes(params[:autocomplete])

    respond_with(@autocomplete)
  end

  # DELETE /admin/autocompletes/1
  # DELETE /admin/autocompletes/1.xml                                              AJAX
  #----------------------------------------------------------------------------
  def destroy
    @autocomplete.destroy

    respond_with(@autocomplete)
  end

  # GET /admin/autocompletes/1/confirm                                             AJAX
  #----------------------------------------------------------------------------
  def confirm
  end
end
