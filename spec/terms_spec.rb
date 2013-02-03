require './lib/terms'
require 'oj'

describe "Terms" do
  before :all do
    terms_stub = Oj.load( '{
                            "@mroth":"Matthew Rothenberg",
                            "@kellan":"Kellan Elliott-McCrea",
                            "@curlyjazz":"Jasmine Trabelsi"
                          }' )
    @terms = Terms.new(terms_stub)
  end

  context "after fresh initialization" do
    it "should not be empty" do
      @terms.list.count.should be > 0
    end
  end

  context "when normalizing terms" do
    it "should convert from hashtag nomenclature to twitter handle" do
      @terms.normalize("MatthewRothenberg").should eq "@mroth"
    end
    it "should convert from Full Name nomenclature to twitter handle" do
      @terms.normalize("Matthew Rothenberg").should eq "@mroth"
    end
    it "should leave a twitter handle alone" do
      @terms.normalize("@mroth").should eq "@mroth"
    end
  end
end