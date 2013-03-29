# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe "/leads/destroy" do
  before do
    login_and_assign
    assign(:lead, @lead = FactoryGirl.create(:lead))
    assign(:lead_status_total, Hash.new(1))
  end

  it "should blind up destroyed lead partial" do
    render
    rendered.should include(%Q/$("lead_#{@lead.id}").visualEffect("blind_up"/)
  end

  it "should update leads sidebar when called from leads index" do
    assign(:leads, [ @lead ].paginate)
    controller.request.env["HTTP_REFERER"] = "http://localhost/leads"
    render

    rendered.should have_rjs("sidebar") do |rjs|
      with_tag("div[id=recently]")
    end
    rendered.should include('$("filters").visualEffect("shake"')
  end

  it "should update pagination when called from leads index" do
    assign(:leads, [ @lead ].paginate)
    controller.request.env["HTTP_REFERER"] = "http://localhost/leads"
    render

    rendered.should have_rjs("paginate")
  end

  it "should update related asset sidebar when called from related asset" do
    assign(:campaign, campaign = FactoryGirl.create(:campaign))
    controller.request.env["HTTP_REFERER"] = "http://localhost/campaigns/#{campaign.id}"
    render

    rendered.should have_rjs("sidebar") do |rjs|
      with_tag("div[class=panel][id=summary]")
      with_tag("div[class=panel][id=recently]")
    end
  end

end

