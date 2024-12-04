#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require "spec_helper"

require_relative "../../support/pages/meetings/new"
require_relative "../../support/pages/structured_meeting/show"
require_relative "../../support/pages/recurring_meeting/show"
require_relative "../../support/pages/meetings/index"

RSpec.describe "Recurring meetings creation",
               :js,
               :with_cuprite,
               with_flag: { recurring_meetings: true } do
  include Components::Autocompleter::NgSelectAutocompleteHelpers

  shared_let(:project) { create(:project, enabled_module_names: %w[meetings]) }
  shared_let(:user) do
    create(:user,
           lastname: "First",
           member_with_permissions: { project => %i[view_meetings create_meetings edit_meetings delete_meetings] }).tap do |u|
      u.pref[:time_zone] = "Etc/UTC"

      u.save!
    end
  end
  shared_let(:other_user) do
    create(:user,
           lastname: "Second",
           member_with_permissions: { project => %i[view_meetings] })
  end
  shared_let(:no_member_user) do
    create(:user,
           lastname: "Third")
  end

  let(:current_user) { user }
  let(:meeting) { RecurringMeeting.order(id: :asc).last }
  let(:show_page) { Pages::RecurringMeeting::Show.new(meeting) }
  let(:meetings_page) { Pages::Meetings::Index.new(project:) }

  context "with a user with permissions" do
    it "can create a recurring meeting" do
      login_as current_user
      meetings_page.visit!
      expect(page).to have_current_path(meetings_page.path)
      meetings_page.click_on "add-meeting-button"
      meetings_page.click_on "Recurring"

      wait_for_network_idle

      meetings_page.set_title "Some title"

      meetings_page.set_start_date "2024-12-31"
      meetings_page.set_start_time "13:30"
      meetings_page.set_duration "1.5"
      meetings_page.set_end_date "2025-01-15"

      click_on "Create meeting"
      wait_for_network_idle
      expect_and_dismiss_flash(type: :success, message: "Successful creation.")

      # Does not send invitation mails by default
      perform_enqueued_jobs
      expect(ActionMailer::Base.deliveries.size).to eq 0

      show_page.visit!

      expect(page).to have_css(".start_time", count: 3)

      show_page.expect_open_meeting date: "12/31/2024 01:30 PM"
      show_page.expect_scheduled_meeting date: "01/07/2025 01:30 PM"
      show_page.expect_scheduled_meeting date: "01/14/2025 01:30 PM"
    end
  end

  context "as a user with viewing permissions only" do
    let(:current_user) { other_user }

    it "does not offer that option" do
      login_as current_user
      meetings_page.visit!
      expect(page).to have_current_path(meetings_page.path)
      expect(page).not_to have_test_selector("add-meeting-button")
    end
  end
end
