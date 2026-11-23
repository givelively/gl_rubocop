# frozen_string_literal: true

require 'yaml'
require 'rubocop'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/no_cross_database_queries'

RSpec.describe GLRubocop::GLCops::NoCrossDatabaseQueries do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new(config) }

  let(:config) do
    defaults = YAML.safe_load_file(File.expand_path('../../../default.yml', __dir__))
    RuboCop::Config.new(
      'AllCops' => { 'DisplayCopNames' => true },
      'GLCops/NoCrossDatabaseQueries' => defaults['GLCops/NoCrossDatabaseQueries']
    )
  end

  before do
    db_groups = {
      'Campaign' => :primary,
      'Nonprofit' => :primary,
      'LineItem' => :primary,
      'Foo::Version' => :primary,
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

    it 'flags includes chained with where referencing the cross-database association table' do
      expect_offense(<<~RUBY)
        Campaign.includes(:salesforce_syncs).where(salesforce_syncs: { success: true })
                                                   ^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not join cross-database association `salesforce_syncs` (versions) from a primary query. Fetch IDs separately and query in two steps.
      RUBY
    end

    it 'flags includes chained with SQL condition referencing the association table' do
      expect_offense(<<~RUBY)
        Campaign.includes(:salesforce_syncs).where('salesforce_syncs.success = true')
                                                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not join cross-database association `salesforce_syncs` (versions) from a primary query. Fetch IDs separately and query in two steps.
      RUBY
    end

    it 'flags where referencing association table followed by includes' do
      expect_offense(<<~RUBY)
        Campaign.where(salesforce_syncs: { success: true }).includes(:salesforce_syncs)
                       ^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not join cross-database association `salesforce_syncs` (versions) from a primary query. Fetch IDs separately and query in two steps.
      RUBY
    end

    it 'flags safe-navigation cross-database joins' do
      expect_offense(<<~RUBY)
        def run
          relation = Campaign.all
          relation&.joins(:salesforce_syncs)
                          ^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not join cross-database association `salesforce_syncs` (versions) from a primary query. Fetch IDs separately and query in two steps.
        end
      RUBY
    end

    it 'resolves receiverless association joins inside non-primary models' do
      expect_no_offenses(<<~RUBY)
        class TrackedWorkflow
          scope :with_events, -> { joins(:workflow_events) }
        end
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
                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not reference `SalesforceSync` (versions) in a primary SQL query. Fetch IDs separately and query in two steps.
      RUBY
    end

    it 'registers an offense for interpolated table_name join on Datawarehouse::LineItem' do
      expect_offense(<<~RUBY)
        Campaign.joins("LEFT JOIN \#{Datawarehouse::LineItem.table_name} ON true")
                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not reference `Datawarehouse::LineItem` (datawarehouse) in a primary SQL query. Fetch IDs separately and query in two steps.
      RUBY
    end

    it 'registers an offense for bare table name passed to from' do
      expect_offense(<<~RUBY)
        Campaign.from('salesforce_syncs')
                      ^^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not reference `salesforce_syncs` (versions) in a primary SQL query. Fetch IDs separately and query in two steps.
      RUBY
    end

    it 'registers an offense for interpolated table name passed to from with alias' do
      expect_offense(<<~RUBY)
        Campaign.from("\#{SalesforceSync.table_name} AS ss")
                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not reference `SalesforceSync` (versions) in a primary SQL query. Fetch IDs separately and query in two steps.
      RUBY
    end

    it 'allows EXTRACT(... FROM column) and JOIN LATERAL on non-primary queries' do
      expect_no_offenses(<<~RUBY)
        AdminSalesforceSync.where('EXTRACT(EPOCH FROM created_at) > 0')
        Datawarehouse::LineItem.joins('JOIN LATERAL (SELECT 1) t ON true')
      RUBY
    end

    it 'allows same-database datawarehouse SQL joins' do
      expect_no_offenses(<<~RUBY)
        Datawarehouse::LineItem.joins('JOIN nonprofits ON nonprofits.id = line_items.nonprofit_id')
        Datawarehouse::LineItem.joins('JOIN unconfigured_dw_table ON unconfigured_dw_table.id = line_items.id')
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
        Campaign.where("source_table = '\#{SalesforceSync.table_name}'")
      RUBY
    end

    it 'registers an offense for schema-qualified SQL table references' do
      expect_offense(<<~RUBY)
        Campaign.joins('JOIN public.salesforce_syncs ON true')
                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not reference `salesforce_syncs` (versions) in a primary SQL query. Fetch IDs separately and query in two steps.
      RUBY
    end

    it 'registers offenses for find_by_sql and SQL subqueries in select/order/group/having' do
      expect_offense(<<~RUBY)
        Campaign.find_by_sql('SELECT * FROM salesforce_syncs')
                             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not reference `salesforce_syncs` (versions) in a primary SQL query. Fetch IDs separately and query in two steps.
        Campaign.select('(SELECT count(*) FROM salesforce_syncs) AS n')
                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not reference `salesforce_syncs` (versions) in a primary SQL query. Fetch IDs separately and query in two steps.
      RUBY
    end

    it 'preserves NonPrimaryTables precedence over colliding primary model names' do
      expect_offense(<<~RUBY)
        Campaign.joins('JOIN versions ON versions.item_id = campaigns.id')
                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not reference `versions` (versions) in a primary SQL query. Fetch IDs separately and query in two steps.
      RUBY
    end

    it 'reports shared primary/datawarehouse tables as primary when queried from versions' do
      expect_offense(<<~RUBY)
        SalesforceSync.joins('JOIN nonprofits ON nonprofits.id = salesforce_syncs.salesforce_syncable_id')
                             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not reference `nonprofits` (primary) in a versions SQL query. Fetch IDs separately and query in two steps.
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
                           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not mix `SalesforceSync` (versions) into a primary query. Fetch IDs separately with pluck before querying.
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

    it 'allows scalar metadata and record creation methods across databases' do
      expect_no_offenses(<<~RUBY)
        Campaign.where(source_type: SalesforceSync.name)
        SalesforceSync.where(salesforce_syncable_type: Campaign.name)
        Campaign.where(id: SalesforceSync.find_or_create_by!(id: 1).salesforce_syncable_id)
        Campaign.where(sync_status: SalesforceSync.statuses[:success])
        Campaign.where(sync_id: SalesforceSync.new(a: 1).salesforce_syncable_id)
        sync = SalesforceSync.new(a: 1)
        Campaign.where(id: sync.salesforce_syncable_id)
      RUBY
    end

    it 'flags receiverless cross-database queries inside an ActiveRecord model class' do
      expect_offense(<<~RUBY)
        class Campaign
          scope :s1, -> { where(SalesforceSync.arel_table[:success].eq(true)) }
                                ^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not mix `SalesforceSync` (versions) into a primary query. Fetch IDs separately with pluck before querying.
          scope :s2, -> { where('EXISTS (SELECT 1 FROM salesforce_syncs)') }
                                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not reference `salesforce_syncs` (versions) in a primary SQL query. Fetch IDs separately and query in two steps.
          def self.s3
            where(id: SalesforceSync.select(:salesforce_syncable_id))
                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not mix `SalesforceSync` (versions) into a primary query. Fetch IDs separately with pluck before querying.
          end
        end
      RUBY
    end

    it 'drops block-local assignments after block exit and handles numblock shadowing' do
      expect_no_offenses(<<~RUBY)
        def run(items)
          items.each do
            inner = SalesforceSync.where(success: true)
            inner.pluck(:id)
          end
          Campaign.where(id: inner)

          _1_outer = SalesforceSync.all
          items.each { _1.where(id: Campaign.select(:id)) }
        end
      RUBY
    end

    it 'restores outer variable database group after shadowed block parameter' do
      expect_no_offenses(<<~RUBY)
        def run
          relation = SalesforceSync.all
          [Campaign.all].each do |relation|
            relation.where(id: Campaign.select(:id))
          end
          relation.where(id: SalesforceSync.select(:id))
        end
      RUBY
    end

    it 'resolves lexical namespace before top-level model names' do
      expect_offense(<<~RUBY)
        module Datawarehouse
          LineItem.where(Campaign.arel_table[:id].eq(1))
                         ^^^^^^^^^^^^^^^^^^^ GLCops/NoCrossDatabaseQueries: Do not mix `Campaign` (primary) into a datawarehouse query. Fetch IDs separately with pluck before querying.
        end
      RUBY
    end

    it 'respects explicit top-level ::Const qualification inside a namespace' do
      expect_no_offenses(<<~RUBY)
        module Datawarehouse
          ::LineItem.where(Campaign.arel_table[:id].eq(1))
        end
      RUBY
    end
  end
end
