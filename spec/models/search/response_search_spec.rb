# tests the search functionality for the response model
require "spec_helper"
include SphinxSupport

describe Response do
  describe "search" do
    before do
      # Deliberately putting a period in form name here. This used to cause issues.
      @form = create(:form, name: 'foo 1.0', question_types: %w(integer))
    end

    it "form qualifier should work" do
      # setup a second form
      @form2 = create(:form, name: 'bar', question_types: %w(integer))

      # create responses
      r1 = create(:response, form: @form)
      r2 = create(:response, form: @form2)
      r3 = create(:response, form: @form)

      assert_search('form:"foo 1.0"', r1, r3)
    end

    # this is all in one test because sphinx is costly to setup and teardown
    it "response full text searches should work", sphinx: true do
      # add long text and short text question
      create(:question, qtype_name: 'long_text', code: 'mauve', add_to_form: @form)
      create(:question, qtype_name: 'text', add_to_form: @form)

      # add two long text questions with explicit codes
      create(:question, qtype_name: 'long_text', code: 'blue', add_to_form: @form)
      create(:question, qtype_name: 'long_text', code: 'Green', add_to_form: @form)

      # add some responses
      r1 = create(:response, form: @form, reviewed: false,
        answer_values: [1, 'the quick brown', 'alpha', 'apple bear cat', 'dog earwax ipswitch'])
      r2 = create(:response, form: @form, reviewed: true,
        answer_values: [1, 'fox heaven jumps', 'bravo', 'fuzzy gusher', 'apple heaven ipswitch'])
      r3 = create(:response, form: @form, reviewed: true,
        answer_values: [1, 'over bravo the lazy brown quick dog', 'contour', 'joker lumpy', 'meal nexttime'])

      do_sphinx_index

      # answers qualifier should work with long_text questions
      assert_search('text:brown', r1, r3)

      # answers qualifier should match short text questions and multiple questions
      assert_search('text:bravo', r2, r3)

      # answers qualifier should be the default
      assert_search('quick brown', r1, r3)

      # exact phrase matching should work
      assert_search(%{text:(quick brown)}, r1, r3) # parenths don't force exact phrase matching
      assert_search(%{text:"quick brown"}, r1)
      assert_search(%{"quick brown"}, r1)

      # question codes should work as qualifiers
      assert_search('text:apple', r1, r2)
      assert_search('{blue}:apple', r1)
      assert_search('{Green}:apple', r2)

      #invalid question codes should raise error
      assert_search('{foo}:bar', error: /'{foo}' is not a valid search qualifier./)

      # using code from other mission should raise error
      # create other mission and question
      other_mission = create(:mission, name: 'other')
      create(:question, qtype_name: 'long_text', code: 'purple', mission: other_mission)
      assert_search('{purple}:bar', error: /valid search qualifier/)
      # now create in the default mission and try again
      create(:question, qtype_name: 'long_text', code: 'purple')
      assert_search('{purple}:bar') # should match nothing, but not error

      # response should only appear once even if it has two matching answers
      assert_search('text:heaven', r2)

      # multiple indexed qualifiers should work
      assert_search('{blue}:lumpy {Green}:meal', r3)
      assert_search('{blue}:lumpy {Green}:ipswitch')

      # mixture of indexed and normal qualifiers should work
      assert_search('{Green}:ipswitch reviewed:1', r2)

      # excerpts should be correct
      assert_excerpts('text:heaven', [
        [{questioning_id: @form.questionings[1].id, code: 'mauve', text: "fox {{{heaven}}} jumps"},
         {questioning_id: @form.questionings[4].id, code: 'Green', text: "apple {{{heaven}}} ipswitch"}]
      ])
      assert_excerpts('{green}:heaven', [
        [{questioning_id: @form.questionings[4].id, code: 'Green', text: "apple {{{heaven}}} ipswitch"}]
      ])
    end

    def assert_search(query, *objs_or_error)
      if objs_or_error[0].is_a?(Hash)
        error_pattern = objs_or_error[0][:error]
        begin
          run_search(query)
        rescue
          assert_match(error_pattern, $!.to_s)
        else
          fail("No error was raised.")
        end
      else
        expect(run_search(query)).to eq(objs_or_error)
      end
    end

    # runs a search with the given query and checks the returned excerpts
    def assert_excerpts(query, excerpts)
      responses = run_search(query, include_excerpts: true)
      expect(responses.size).to eq(excerpts.size)
      responses.each_with_index{|r,i| expect(r.excerpts).to eq(excerpts[i])}
    end

    def run_search(query, options = {})
      options[:include_excerpts] ||= false
      Response.do_search(Response.unscoped, query, {mission: get_mission}, options)
    end
  end
end