require "rails_helper"

describe Handlers::EnrollmentEventXmlHelper do
  subject { Class.new { extend Handlers::EnrollmentEventXmlHelper } }

  describe "#extract_subscriber" do
    let(:subscriber) { instance_double(Enrollee) }
    let(:dependent) { instance_double(Enrollee) }

    let(:policy_cv) { double(:enrollees => [subscriber, dependent]) }

    before do
      allow(subscriber).to receive(:subscriber?).and_return(true)
      allow(dependent).to receive(:subscriber?).and_return(false)
    end
    it "returns the subscriber only" do
      expect(subject.extract_subscriber(policy_cv)).to eq(subscriber)
    end
  end

  describe "#extract_member_id" do
    let(:enrollee) { double('Enrollee', :member => member, :value => self) }
    let(:member) { instance_double(Member, id: "ABC#54")}

    it "returns the numeric id" do
      expect(subject.extract_member_id(enrollee)).to eq("54")
    end
  end

  describe "#extract_enrollee_start" do
    let(:benefit) { double(:begin_date => "20170101") }
    let(:enrollee) { double(:benefit => benefit)}
    it "returns the parsed date" do
      expect(subject.extract_enrollee_start(enrollee)).to eq(Date.new(2017,1,1))
    end
  end

  describe "#extract_enrollee_end" do
    let(:benefit) { double(:end_date => "20170101") }
    let(:enrollee) { double(:benefit => benefit)}
    it "returns the parsed date" do
      expect(subject.extract_enrollee_end(enrollee)).to eq(Date.new(2017,1,1))
    end
  end

  describe "#extract_enrollment_group_id" do
    let(:policy_cv) { double(:id => "SOMEGRP#1234") }
    it "returns the parsed id" do
      expect(subject.extract_enrollment_group_id(policy_cv)).to eq("1234")
    end
  end

  describe "#extract_policy_member_ids" do
    let(:subscriber) { instance_double(Member, id: 1) }
    let(:dependent) { instance_double(Member, id: 2) }
    let(:enrollee_sub) { double(:member => subscriber) }
    let(:enrollee_dep) { double(:member => dependent) }
    let(:policy_cv) { double(:enrollees => [enrollee_sub,enrollee_dep]) }

    it "returns the ids" do
      expect(subject.extract_policy_member_ids(policy_cv)).to eq([1,2])
    end
  end

  describe '#extract_employer_link' do
    let(:shop_market) { double(:employer_link => :employer_link)}
    let(:policy) { double(:policy, :shop_market => shop_market) }
    let(:policy_cv) { double(:policy_enrollment => policy)}

    it "returns the employer link" do
      expect(subject.extract_employer_link(policy_cv)).to eq(:employer_link)
    end
  end

  describe "#find_employer" do
    let(:policy_cv) { double }
    let(:employer_link) { double(:id => "SOMELINK#VALUE")}
    before do
      allow(subject).to receive(:extract_employer_link).with(policy_cv).and_return(employer_link)
      allow(Employer).to receive(:where).with(hbx_id: 'VALUE').and_return([:employer])
    end

    it "finds the employer" do
      expect(subject.find_employer(policy_cv)).to eq(:employer)
    end
  end

  describe "#find_employer_plan_year" do
    let(:policy_cv) { double }
    let(:employer) { double }
    let(:subscriber) { double }
    before do
      allow(subject).to receive(:find_employer).with(policy_cv).and_return(employer)
      allow(subject).to receive(:extract_subscriber).with(policy_cv).and_return(subscriber)
      allow(subject).to receive(:extract_enrollee_start).with(subscriber).and_return(:start_date)
      allow(employer).to receive(:plan_year_of).with(:start_date).and_return(:start_year)
    end
    it "returns the plan year" do
      expect(subject.find_employer_plan_year(policy_cv)).to eq(:start_year)
    end
  end

  describe "#extract_plan" do
    let(:policy_cv) { double }
    before do
      allow(subject).to receive(:extract_hios_id).with(policy_cv).and_return(:hios_id)
      allow(subject).to receive(:extract_active_year).with(policy_cv).and_return("2016")
      allow(Plan).to receive(:where).with(:hios_plan_id => :hios_id, :year => 2016).and_return([:plan])
    end
    it "extracts the plan" do
      expect(subject.extract_plan(policy_cv)).to eq(:plan)
    end
  end
end
