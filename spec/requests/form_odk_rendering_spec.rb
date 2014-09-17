require 'spec_helper'
require 'xml'

# We need to clean with truncation here b/c we use hard coded id's in expectation.
describe 'form rendering for odk', clean_with_truncation: true do
  before do
    @user = create(:user)
    @form = create(:sample_form)
    @form.publish!
    login(@user)
    get(form_path(@form, format: :xml))
  end

  it 'should render proper xml' do
    expect(response).to be_success

    # Parse the XML and tidy.
    doc = XML::Parser.string(response.body, options: XML::Parser::Options::NOBLANKS).parse
    expect(doc.to_s).to eq File.read(File.expand_path('../../expectations/sample_form_odk.xml', __FILE__))
  end
end
