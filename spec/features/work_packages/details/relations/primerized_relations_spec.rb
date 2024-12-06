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

RSpec.describe "Primerized work package relations tab",
               :js, :with_cuprite do
  include Components::Autocompleter::NgSelectAutocompleteHelpers

  shared_let(:user) { create(:admin) }
  shared_let(:project) { create(:project) }

  before_all do
    set_factory_default(:user, user)
    set_factory_default(:project, project)
    set_factory_default(:project_with_types, project)
  end

  shared_let(:parent_work_package) { create(:work_package, subject: "parent") }
  shared_let(:work_package) { create(:work_package, subject: "main", parent: parent_work_package) }
  shared_let(:type1) { create(:type) }
  shared_let(:type2) { create(:type) }

  shared_let(:wp_predecessor) do
    create(:work_package, type: type1, subject: "predecessor of main",
                          start_date: Date.current, due_date: Date.current + 1.week)
  end
  shared_let(:wp_related) { create(:work_package, type: type2, subject: "related to main") }
  shared_let(:wp_blocker) { create(:work_package, type: type1, subject: "blocks main") }

  shared_let(:relation_follows) do
    create(:relation,
           from: work_package,
           to: wp_predecessor,
           relation_type: Relation::TYPE_FOLLOWS)
  end
  shared_let(:relation_relates) do
    create(:relation,
           from: work_package,
           to: wp_related,
           relation_type: Relation::TYPE_RELATES)
  end
  shared_let(:relation_blocked) do
    create(:relation,
           from: wp_blocker,
           to: work_package,
           relation_type: Relation::TYPE_BLOCKED)
  end
  shared_let(:child_wp) do
    create(:work_package,
           parent: work_package,
           type: type1,
           project: project)
  end
  shared_let(:not_yet_child_wp) do
    create(:work_package,
           type: type1,
           project:)
  end

  let(:full_wp_view) { Pages::FullWorkPackage.new(work_package) }
  let(:relations_tab) { Components::WorkPackages::Relations.new(work_package) }
  let(:relations_panel_selector) { ".detail-panel--relations" }
  let(:relations_panel) { find(relations_panel_selector) }
  let(:work_packages_page) { Pages::PrimerizedSplitWorkPackage.new(work_package) }
  let(:tabs) { Components::WorkPackages::PrimerizedTabs.new }

  current_user { user }

  def label_for_relation_type(relation_type)
    I18n.t("work_package_relations_tab.relations.label_#{relation_type}_plural").capitalize
  end

  before do
    work_packages_page.visit_tab!("relations")
    expect_angular_frontend_initialized
    work_packages_page.expect_subject
    loading_indicator_saveguard
  end

  describe "rendering" do
    it "renders the relations tab" do
      scroll_to_element relations_panel

      wait_for_network_idle

      expect(page).to have_css(relations_panel_selector)

      tabs.expect_counter("relations", 4)

      relations_tab.expect_relation(relation_follows)
      relations_tab.expect_relation(relation_relates)
      relations_tab.expect_relation(relation_blocked)
    end
  end

  describe "deletion" do
    it "can delete relations" do
      scroll_to_element relations_panel

      wait_for_network_idle

      relations_tab.remove_relation(relation_follows)

      expect { relation_follows.reload }.to raise_error(ActiveRecord::RecordNotFound)

      tabs.expect_counter("relations", 3)
    end

    it "can delete children" do
      scroll_to_element relations_panel

      wait_for_network_idle

      relations_tab.remove_child(child_wp)
      expect(child_wp.reload.parent).to be_nil

      tabs.expect_counter("relations", 3)
    end
  end

  describe "editing" do
    it "renders an edit form" do
      scroll_to_element relations_panel

      wait_for_network_idle

      relation_row = relations_tab.expect_relation(relation_follows)

      relations_tab.add_description_to_relation(relation_follows, "Discovered relations have descriptions!")

      # Reflects new description
      expect(relation_row).to have_text("Discovered relations have descriptions!")

      # Unchanged
      tabs.expect_counter("relations", 4)

      # Edit again
      relations_tab.edit_relation_description(relation_follows, "And they can be edited!")

      # Reflects new description
      expect(relation_row).to have_text("And they can be edited!")

      # Unchanged
      tabs.expect_counter("relations", 4)
    end

    it "does not have an edit action for children" do
      scroll_to_element relations_panel

      wait_for_network_idle

      child_row = relations_panel.find("[data-test-selector='op-relation-row-#{child_wp.id}']")

      within(child_row) do
        page.find("[data-test-selector='op-relation-row-#{child_wp.id}-action-menu']").click
        expect(page).to have_no_css("[data-test-selector='op-relation-row-#{child_wp.id}-edit-button']")
      end
    end

    context "with the shown WorkPackage being the 'to' relation part" do
      let(:another_wp) { create(:work_package, type: type2, subject: "related to main") }

      let(:relation_to) do
        create(:relation,
               from: another_wp,
               to: work_package,
               relation_type: Relation::TYPE_FOLLOWS)
      end

      before do
        another_wp
        relation_to
      end

      it "shows the correct related WorkPackage in the dialog (regression #59771)" do
        scroll_to_element relations_panel

        wait_for_network_idle

        relations_tab.expect_relation(another_wp)
        relations_tab.open_relation_dialog(another_wp)

        within "##{WorkPackageRelationsTab::WorkPackageRelationDialogComponent::DIALOG_ID}" do
          expect(page).to have_field("Work package",
                                     readonly: true,
                                     with: "#{another_wp.type.name.upcase} ##{another_wp.id} - #{another_wp.subject}")
        end
      end
    end
  end

  describe "creating a relation" do
    let(:wp_successor) { create(:work_package, type: type1, subject: "successor of main") }

    it "renders the new relation form for the selected type and creates the relation" do
      scroll_to_element relations_panel

      wait_for_network_idle

      relations_tab.add_relation(type: :precedes, relatable: wp_successor,
                                 description: "Discovered relations have descriptions!")
      relations_tab.expect_relation(wp_successor)

      # Bumped by one
      tabs.expect_counter("relations", 5)
      # Relation is created
      expect(Relation.follows.where(from: wp_successor, to: work_package)).to exist
    end

    it "does not autocomplete unrelatable work packages" do
      # wp_predecessor is already related to work_package as relation_follows
      # in a predecessor relation, so it should not be autocompleteable anymore
      # under the "Predecessor (before)" type
      relations_tab.select_relation_type "Predecessor (before)"

      wait_for_reload

      within "##{WorkPackageRelationsTab::WorkPackageRelationFormComponent::DIALOG_ID}" do
        expect(page).to have_text("Add predecessor (before)")

        autocomplete_field = page.find("[data-test-selector='work-package-relation-form-to-id']")
        search_autocomplete(autocomplete_field,
                            query: wp_predecessor.subject,
                            results_selector: "body")
        expect_no_ng_option(autocomplete_field,
                            wp_predecessor.subject,
                            results_selector: "body")
      end
    end
  end

  describe "attaching a child" do
    it "renders the new child form and creates the child relationship" do
      scroll_to_element relations_panel

      wait_for_network_idle

      tabs.expect_counter("relations", 4)

      relations_tab.add_existing_child(not_yet_child_wp)
      relations_tab.expect_child(not_yet_child_wp)

      # Bumped by one
      tabs.expect_counter("relations", 5)
    end

    it "doesn't autocomplete parent, children, and WP itself" do
      relations_tab.select_relation_type "Child"

      wait_for_reload

      within "##{WorkPackageRelationsTab::AddWorkPackageChildFormComponent::DIALOG_ID}" do
        autocomplete_field = page.find("[data-test-selector='work-package-child-form-id']")

        # It doesn't autocomplete children
        search_autocomplete(autocomplete_field,
                            query: child_wp.subject,
                            results_selector: "body")

        expect_no_ng_option(autocomplete_field,
                            child_wp.subject,
                            results_selector: "body")

        # It doesn't autocomplete parent
        search_autocomplete(autocomplete_field,
                            query: parent_work_package.subject,
                            results_selector: "body")

        expect_no_ng_option(autocomplete_field,
                            parent_work_package.subject,
                            results_selector: "body")

        # It doesn't autocomplete work package itself
        search_autocomplete(autocomplete_field,
                            query: work_package.id,
                            results_selector: "body")

        expect_no_ng_option(autocomplete_field,
                            work_package.id,
                            results_selector: "body")
      end
    end
  end

  describe "with limited permissions" do
    let(:no_permissions_role) { create(:project_role, permissions: %i[view_work_packages]) }
    let(:user_without_permissions) do
      create(:user,
             member_with_roles: { project => no_permissions_role })
    end
    let(:current_user) { user_without_permissions }

    it "does not show options to add or edit relations" do
      scroll_to_element relations_panel

      wait_for_network_idle

      tabs.expect_counter("relations", 4)

      relations_tab.expect_no_add_relation_button
      relations_tab.expect_no_relatable_action_menu(wp_related)
      relations_tab.expect_no_relatable_action_menu(child_wp)
    end

    context "with manage_relations permissions" do
      let(:no_permissions_role) do
        create(:project_role, permissions: %i(view_work_packages edit_work_packages manage_work_package_relations))
      end

      it "does not show the option to delete the child" do
        scroll_to_element relations_panel

        wait_for_network_idle

        tabs.expect_counter("relations", 4)

        # The menu is shown as the user can add a relation
        relations_tab.expect_add_relation_button

        # The relation can be edited and deleted
        relations_tab.expect_relatable_action_menu(wp_related)
        relations_tab.relatable_action_menu(wp_related).click
        relations_tab.expect_relatable_delete_button(wp_related)

        # The child cannot be changed
        relations_tab.expect_no_relatable_action_menu(child_wp)
      end
    end

    context "with manage_subtasks permissions" do
      let(:no_permissions_role) { create(:project_role, permissions: %i(view_work_packages edit_work_packages manage_subtasks)) }

      it "does not show the option to edit the relation but only the child" do
        scroll_to_element relations_panel

        wait_for_network_idle

        tabs.expect_counter("relations", 4)

        # The menu is shown as the user can add a child
        relations_tab.expect_add_relation_button

        # The relation cannot be edited
        relations_tab.expect_no_relatable_action_menu(wp_related)

        # The child can be removed
        relations_tab.expect_relatable_action_menu(child_wp)
        relations_tab.relatable_action_menu(child_wp).click
        relations_tab.expect_relatable_delete_button(child_wp)
      end
    end
  end
end
