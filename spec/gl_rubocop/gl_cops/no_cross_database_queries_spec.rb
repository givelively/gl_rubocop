# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/no_cross_database_queries'

RSpec.describe GLRubocop::GLCops::NoCrossDatabaseQueries do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new }

  before do
    db_groups = {
      'Campaign' => :primary,
      'Nonprofit' => :primary,
      'LineItem' => :primary,
      'SalesforceSync' => :versions,
      'AdminSalesforceSync' => :versions,
      'Version' => :versions,
      'TrackedWorkflow' => :versions,
      'WorkflowEvent' => :versions,
      'Datawarehouse::LineItem' => :datawarehouse
    }
    allow(GLRubocop::Helpers::ActiveRecordModelRegistry)
      .to receive(:database_groups_for)
      .and_return(db_groups)
  end

  context 'with association joins and references' do
    it 'registers an offense for joins(:salesforce_syncs) on a primary model' do
      expect_offense(<<~RUBY)
        Campaign.joins(:salesforce_syncs)
                       ^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not join cross-database association `salesforce_syncs` (versions) from a primary query. Fetch IDs separately and query in two steps.
      RUBY
    end

    it 'registers an offense for left_joins(:salesforce_syncs)' do
      expect_offense(<<~RUBY)
        Nonprofit.left_joins(:salesforce_syncs)
                             ^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not join cross-database association `salesforce_syncs` (versions) from a primary query. Fetch IDs separately and query in two steps.
      RUBY
    end

    it 'registers an offense for left_outer_joins(:versions)' do
      expect_offense(<<~RUBY)
        Campaign.left_outer_joins(:versions)
                                  ^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not join cross-database association `versions` (versions) from a primary query. Fetch IDs separately and query in two steps.
      RUBY
    end

    it 'registers an offense for nested joins including :salesforce_syncs' do
      expect_offense(<<~RUBY)
        Nonprofit.joins(campaigns: :salesforce_syncs)
                                   ^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not join cross-database association `salesforce_syncs` (versions) from a primary query. Fetch IDs separately and query in two steps.
      RUBY
    end

    it 'registers an offense for includes(:salesforce_syncs).references(:salesforce_syncs)' do
      expect_offense(<<~RUBY)
        Campaign.includes(:salesforce_syncs).references(:salesforce_syncs)
                                                        ^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not join cross-database association `salesforce_syncs` (versions) from a primary query. Fetch IDs separately and query in two steps.
      RUBY
    end

    it 'does not flag includes(:salesforce_syncs) or preload without references' do
      expect_no_offenses(<<~RUBY)
        Campaign.includes(:salesforce_syncs)
        Campaign.preload(:salesforce_syncs)
      RUBY
    end

    it 'does not register an offense for same-database joins within versions' do
      expect_no_offenses(<<~RUBY)
        TrackedWorkflow.joins(:workflow_events)
      RUBY
    end
  end

  context 'with raw SQL joins and table references' do
    it 'registers an offense for raw SQL join on salesforce_syncs' do
      expect_offense(<<~RUBY)
        Campaign.joins('INNER JOIN salesforce_syncs ON salesforce_syncs.salesforce_syncable_id = campaigns.id')
                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not reference `salesforce_syncs` (versions) in a primary SQL query. Fetch IDs separately and query in two steps.
      RUBY
    end

    it 'registers an offense for interpolated table_name join on SalesforceSync' do
      expect_offense(<<~RUBY)
        Campaign.joins("LEFT JOIN \#{SalesforceSync.table_name} ON true")
                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not reference `salesforce_syncs` (versions) in a primary SQL query. Fetch IDs separately and query in two steps.
      RUBY
    end

    it 'registers an offense for raw SQL join from a versions model to a primary table' do
      expect_offense(<<~RUBY)
        AdminSalesforceSync.joins('INNER JOIN campaigns ON campaigns.id = salesforce_syncs.salesforce_syncable_id')
                                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not reference `campaigns` (primary) in a versions SQL query. Fetch IDs separately and query in two steps.
      RUBY
    end

    it 'registers an offense for EXISTS subquery referencing salesforce_syncs in where' do
      expect_offense(<<~RUBY)
        Campaign.where('EXISTS (SELECT 1 FROM salesforce_syncs WHERE salesforce_syncable_id = campaigns.id)')
                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not reference `salesforce_syncs` (versions) in a primary SQL query. Fetch IDs separately and query in two steps.
      RUBY
    end

    it 'does not register an offense for plain string values mentioning versions' do
      expect_no_offenses(<<~RUBY)
        Campaign.where(description: 'versions')
      RUBY
    end
  end

  context 'with arel_table and relation subqueries' do
    it 'registers an offense when mixing SalesforceSync.arel_table into a primary query' do
      expect_offense(<<~RUBY)
        Campaign.where(SalesforceSync.arel_table[:success].eq(true))
                       ^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not mix `SalesforceSync` (versions) into a primary query. Fetch IDs separately with pluck before querying.
      RUBY
    end

    it 'registers an offense when mixing Campaign.arel_table into a versions query' do
      expect_offense(<<~RUBY)
        AdminSalesforceSync.where(Campaign.arel_table[:nonprofit_id].eq(nonprofit_id))
                                  ^^^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not mix `Campaign` (primary) into a versions query. Fetch IDs separately with pluck before querying.
      RUBY
    end

    it 'registers an offense when passing a primary correlated relation into AdminSalesforceSync' do
      expect_offense(<<~RUBY)
        def filter(nonprofit_id)
          correlated = Campaign.where(nonprofit_id: nonprofit_id)
          AdminSalesforceSync.where(correlated.arel.exists)
                                    ^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not mix `correlated` (primary) into a versions query. Fetch IDs separately with pluck before querying.
        end
      RUBY
    end

    it 'flags an unmaterialized SalesforceSync relation inside primary where' do
      expect_offense(<<~RUBY)
        Campaign.where(id: SalesforceSync.where(success: true).select(:salesforce_syncable_id))
                           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not mix `SalesforceSync` (versions) into a primary query. Fetch IDs separately with pluck before querying.
      RUBY
    end

    it 'registers an offense when mixing Datawarehouse::LineItem.arel_table into a primary query' do
      expect_offense(<<~RUBY)
        Campaign.where(Datawarehouse::LineItem.arel_table[:id].eq(1))
                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not mix `Datawarehouse::LineItem` (datawarehouse) into a primary query. Fetch IDs separately with pluck before querying.
      RUBY
    end

    it 'flags mixing SalesforceSync.arel_table with another arel_table on an untyped relation' do
      expect_offense(<<~RUBY)
        def apply_filter(relation)
          relation.where(
            relation.klass.arel_table[:id].eq(SalesforceSync.arel_table[:salesforce_syncable_id])
                                              ^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not mix `SalesforceSync` (versions) into a primary query. Fetch IDs separately with pluck before querying.
          )
        end
      RUBY
    end

    it 'does not register an offense when pluck materializes IDs first' do
      expect_no_offenses(<<~RUBY)
        def synced_campaigns
          ids = SalesforceSync.where(success: true).pluck(:salesforce_syncable_id)
          Campaign.where(id: ids)
        end

        Campaign.where(id: SalesforceSync.where(success: true).pluck(:salesforce_syncable_id))
      RUBY
    end

    it 'allows SalesforceSync.arel_table on a versions association' do
      expect_no_offenses(<<~RUBY)
        nonprofit.salesforce_syncs.where(SalesforceSync.arel_table[:success].eq(false))
      RUBY
    end

    it 'allows Datawarehouse::LineItem.arel_table on its own model' do
      expect_no_offenses(<<~RUBY)
        Datawarehouse::LineItem.order(Datawarehouse::LineItem.arel_table[:date].desc)
      RUBY
    end
  end
end
