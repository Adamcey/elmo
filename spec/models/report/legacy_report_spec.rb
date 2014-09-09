require 'spec_helper'

# This spec covers behavior common to all legacy report types.
describe Report::LegacyReport do
  before do
    @form = create(:form, question_types: %w(select_one integer text))
  end

  context 'when calculation question destroyed' do
    before do
      # Create a ListReport with three calculations, then destroy the question.
      @report = create(:list_report, _calculations: [@form.questions[0], 'submitter', 'source'])
      @form.questions[0].destroy
    end

    it 'should lose calculation and fix other calculations' do
      @report.reload
      expect(@report.calculations.map(&:attrib1_name)).to eq %w(submitter source)
      expect(@report.calculations.map(&:rank)).to eq [1,2]
    end
  end

  context 'when last calculations question destroyed' do
    before do
      @report = create(:list_report, _calculations: [@form.questions[0]])
      @form.questions[0].destroy
    end

    it 'should destroy self' do
      expect(Report::Report.exists?(@report)).to be false
    end
  end
end
