# tests the general case of summary collections, where there are multiple subsets in the collection
# makes sure that the data is disaggregated properly
# tests for the singleton case, where there is only one subset in the collection, are currently in QuestionSummaryTest

require 'test_helper'
require 'unit/report/report_test_helper'

class Report::SummaryCollectionTest < ActiveSupport::TestCase
  test "collection should have proper disagg values" do
    # build a form with two questions: the one we want to analyze and the one we want to disaggregate by
    prepare_form_and_collection('integer', 'select_one', {'a' => [1,2,4], 'b' => [8,9]})
    options = @form.questionings[1].options
    assert_equal(options[0], @collection.subsets[0].disagg_value)
    assert_equal(options[1], @collection.subsets[1].disagg_value)
  end

  test "collections with integer questions should have correct summaries" do
    prepare_form_and_collection('integer', 'select_one', {'a' => [1,2,4,6], 'b' => [8,9]})
    assert_equal(3.25, @collection.subsets[0].summaries[0].items[0].stat) # mean
    assert_equal(1, @collection.subsets[0].summaries[0].items[1].stat) # min
    assert_equal(6, @collection.subsets[0].summaries[0].items[2].stat) # max
    assert_equal(8.5, @collection.subsets[1].summaries[0].items[0].stat) # mean
    assert_equal(8, @collection.subsets[1].summaries[0].items[1].stat) # min
    assert_equal(9, @collection.subsets[1].summaries[0].items[2].stat) # max
  end

  test "collections with select_one questions should have correct summaries" do
    prepare_form_and_collection('select_one', 'select_one', {'a' => ['red', 'red', 'blue'], 'b' => ['blue', 'red', 'blue', 'blue']})
    assert_equal(2, @collection.subsets[0].summaries[0].items[0].count) # a - red
    assert_equal(1, @collection.subsets[0].summaries[0].items[1].count) # a - blue
    assert_equal(1, @collection.subsets[1].summaries[0].items[0].count) # b - red
    assert_equal(3, @collection.subsets[1].summaries[0].items[1].count) # b - blue
  end

  test "collections with select_multiple questions should have correct summaries" do
    prepare_form_and_collection('select_multiple', 'select_one', 
      {'a' => [['red'], ['red', 'green'], []], 'b' => [['blue', 'red'], ['blue', 'green']]})
    assert_equal(2, @collection.subsets[0].summaries[0].items[0].count) # a - red
    assert_equal(0, @collection.subsets[0].summaries[0].items[1].count) # a - blue
    assert_equal(1, @collection.subsets[0].summaries[0].items[2].count) # a - green
    assert_equal(1, @collection.subsets[1].summaries[0].items[0].count) # b - red
    assert_equal(2, @collection.subsets[1].summaries[0].items[1].count) # b - blue
    assert_equal(1, @collection.subsets[1].summaries[0].items[2].count) # b - green
  end

  test "collections with date questions should have correct summaries" do
    prepare_form_and_collection('date', 'select_one', 
      {'a' => %w(2012-10-26 2011-07-22 2012-10-26), 'b' => %w(2013-07-22 2012-9-22 2013-07-22 2013-07-22)})

    # check that headers are correct and in correct order
    assert_equal(['Jul 22 2011', 'Oct 26 2012'], header_names_for_disagg_value('a'))
    assert_equal(['Sep 22 2012', 'Jul 22 2013'], header_names_for_disagg_value('b'))
  end

  test "collection subsets should be correct if no answers for one of the options" do
    prepare_form_and_collection('integer', 'select_one', {'a' => [1,2,4,6], 'b' => [8,9], 'c' => []})
    options = @form.questionings[1].options

    # subset should still be created
    assert_equal(options[2], @collection.subsets[2].disagg_value)

    # but should be marked no_data
    assert_equal(true, @collection.subsets[2].no_data?)    
  end

  test "collection should work if there are no answers at all" do
    prepare_form_and_collection('integer', 'select_one', {'a' => [], 'b' => []})

    # collection should be marked no_data
    assert_equal(true, @collection.no_data?)
  end

  test "the disaggregation question should not be included in the report output" do
    # since otherwise it would always be 100% in one column and 0% in the others
  end

  private
    def prepare_form_and_collection(*args)
      prepare_form(*args)
      prepare_collection
    end

    def prepare_form(analyze_type, dissag_type, answers_by_dissag_value)
      # create form
      @form = FactoryGirl.create(:form)

      # if the analyze question is a select type, use red blue green as option set (ignored otherwise)
      analyze_q = FactoryGirl.create(:question, :qtype_name => analyze_type, :option_names => %w(red blue green))

      # add the disagg question
      disagg_q = FactoryGirl.create(:question, :qtype_name => dissag_type, :option_names => answers_by_dissag_value.keys)
      
      @form.questions << analyze_q << disagg_q
      @form.save!

      # convert answers to array of arrays
      answers = answers_by_dissag_value.map{|dissag_value, values| values.map{|v| [v, dissag_value]}}.flatten(1)

      # randomize to make sure they're untangled properly later
      answers.shuffle!

      # build the responses
      answers.each{|a| FactoryGirl.create(:response, :form => @form, :_answers => a)}
    end

    def prepare_collection
      # pass the full questionings array, and the disaggregation questioning, which is the last one
      @collection = Report::SummaryCollectionBuilder.new(@form.questionings, @form.questionings.last).build
    end

    def subsets_by_disagg_value
      @subsets_by_disagg_value ||= @collection.subsets.index_by{|s| s.disagg_value.name}
    end

    def header_names_for_disagg_value(val)
      # the question we're interested in is always rank 1
      subsets_by_disagg_value[val].summaries.detect{|s| s.questioning.rank == 1}.headers.map{|h| h[:name]}
    end
end